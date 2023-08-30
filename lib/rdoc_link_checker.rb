# frozen_string_literal: true

require 'nokogiri'
require 'rexml/document'
require 'find'
require 'net/http'
require 'json'

require_relative 'rdoc_link_checker/version'

class RDocLinkChecker

  include REXML

  attr_accessor :html_dirpath, :config_filepath, :onsite_only, :no_toc,
                :source_file_omits

  attr_accessor :source_paths, :pages

  def initialize(
    html_dirpath,
    config_filepath: nil,
    onsite_only: false,
    no_toc: false
  )
    self.html_dirpath = html_dirpath
    self.config_filepath = config_filepath
    self.onsite_only = onsite_only
    self.no_toc = no_toc
    self.source_file_omits = []
    if config_filepath
      config = JSON.parse(File.read(config_filepath))
      options = config['options']
      if options
        val = options['onsite_only']
        self.onsite_only = val if val
        val = options['no_toc']
        self.no_toc = val if val
      end
      regexp_sources = config['source_file_omits']
      if regexp_sources
        regexp_sources.each do |regexp_source|
          self.source_file_omits.push(Regexp.new(regexp_source))
        end
      end
    end
    self.pages = {}
    @counts = {
      source_pages: 0,
      target_pages: 0,
      links_checked: 0,
      links_broken: 0,
    }
  end

  def check
    # All work is done in the HTML directory,
    # and that is where Report.htm will be put.
    Dir.chdir(html_dirpath) do |dir|
      @counts[:start_time] = Time.new
      gather_source_paths
      create_source_pages
      create_target_pages
      verify_links
      @counts[:end_time] = Time.new
      report
    end
  end

  # Gather paths to source HTML pages.
  def gather_source_paths
    paths = []
    paths = Find.find('.').select {|path| path.end_with?('.html') }
    # Remove leading './'.
    self.source_paths = paths.map{|path| path.sub(%r[^\./], '')}
    source_file_omits.each do |re|
      self.source_paths.delete_if do |source_path|
        source_path.match(re)
      end
    end
    @counts[:source_pages] = source_paths.size
  end

  # Create a source \Page object for each source path.
  # Gather its links and ids.
  def create_source_pages
    source_paths.sort.each_with_index do |source_path, i|
      source_page = Page.new(:source, source_path, onsite_only, pages: pages, counts: @counts)
      pages[source_path] = source_page
      source_page.content_type = 'text/html'
      source_text = File.read(source_path)
      doc = Nokogiri::HTML(source_text)
      if source_path == 'table_of_contents.html'
        source_page.gather_links(doc) unless no_toc
      else
        source_page.gather_links(doc)
      end
      source_page.gather_link_targets(doc)
    end
  end

  # Create a target \Page object for each link
  # (unless already created as a source page).
  def create_target_pages
    doc = nil
    target_page_count = 0
    source_paths = pages.keys
    source_paths.each do |source_path|
      # Need for relative links to work.
      dirname = File.dirname(source_path)
      Dir.chdir(dirname) do
        source_page = pages[source_path]
        source_page.links.each_with_index do |link, i|
          next if link.path.nil?
          target_path = link.real_path
          if pages[target_path]
            target_page = pages[target_path]
          else
            target_page_count += 1
            target_page = Page.new(:target, target_path, onsite_only, pages: pages, counts: @counts)
            pages[target_path] = target_page
            if File.readable?(link.path)
              target_text = File.read(link.path)
              doc = Nokogiri::HTML(target_text)
              target_page.gather_link_targets(doc)
            elsif RDocLinkChecker.checkable?(link.path)
              link.exception = fetch(link.path, target_page)
              link.valid_p = false if link.exception
            else
              # File not readable or checkable.
            end
          end
          next if target_page.nil?
          if link.has_fragment? && target_page.ids.empty?
            doc || doc = Nokogiri::HTML(target_text)
            target_page.gather_link_targets(doc) if target_page.content_type&.match('html')
          end
        end
      end
    end
    @counts[:target_pages] = target_page_count
  end

  # Verify that each link target exists.
  def verify_links
    linking_pages = pages.select do |path, page|
      !page.links.empty?
    end
    link_count = 0
    broken_count = 0
    linking_pages.each_pair do |path, page|
      link_count += page.links.size
      page.links.each_with_index do |link, i|
        if link.valid_p.nil? # Don't disturb if already set to false.
          target_page = pages[link.real_path]
          if target_page
            target_id = link.fragment
            link.valid_p = target_id.nil? ||
              target_page.ids.include?(target_id) ||
              !target_page.content_type&.match('html')
          else
            link.valid_p = false
          end
        end
        broken_count += 1 unless link.valid_p
      end
    end
    @counts[:links_checked] = link_count
    @counts[:links_broken] = broken_count
  end

  # Fetch the page from the web and gather its ids into the target page.
  # Returns exception or nil.
  def fetch(url, target_page)
    code = 0
    exception = nil
    begin
      response =  Net::HTTP.get_response(URI(url))
      code = response.code.to_i
      target_page.code = code
      target_page.content_type = response['Content-Type']
    rescue => x
      raise unless x.class.name.match(/^(Net|SocketError|IO::TimeoutError|Errno::)/)
      exception = RDocLinkChecker::HttpResponseError.new(url, x)
    end
    # Don't load if bad code, or no response, or if not html.
    if !code_bad?(code)
      if content_type_html?(response)
        doc = Nokogiri::HTML(response.body)
        target_page.gather_link_targets(doc)
      end
    end
    exception
  end

  # Returns whether the code is bad (zero or >= 400).
  def code_bad?(code)
    return false if code.nil?
    (code == 0) || (code >= 400)
  end

  # Returns whether the response body should be HTML.
  def content_type_html?(response)
    return false unless response
    return false unless response['Content-Type']
    response['Content-Type'].match('html')
  end

  # Returns whether the path is offsite.
  def self.offsite?(path)
    path.start_with?('http')
  end

  # Returns the string fragment for the given path or ULR, or +nil+
  def self.get_fragment(s)
    a = s.split('#', 2)
    a.size == 2 ? a[1] : nil
  end

  # Returns whether the path is checkable.
  def self.checkable?(path)
    return false unless path
    begin
      uri = URI(path)
      return ['http', 'https', nil].include?(uri.scheme)
    rescue
      return false
    end
  end

  # Generate the report; +checker+ is the \RDocLinkChecker object.
  def report

    doc = Document.new('')
    root = doc.add_element(Element.new('root'))

    head = root.add_element(Element.new('head'))
    title = head.add_element(Element.new('title'))
    title.text = 'RDocLinkChecker Report'
    style = head.add_element(Element.new('style'))
    style.text = <<EOT
*        { font-family: sans-serif }
.data    { font-family: courier }
.center  { text-align: center }
.good    { color: rgb(  0,  97,   0); background-color: rgb(198, 239, 206) } /* Greenish */
.iffy    { color: rgb(156, 101,   0); background-color: rgb(255, 235, 156) } /* Yellowish */
.bad     { color: rgb(156,   0,   6); background-color: rgb(255, 199, 206) } /* Reddish */
.neutral { color: rgb(  0,   0,   0); background-color: rgb(217, 217, 214) } /* Grayish */
EOT

    body = root.add_element(Element.new('body'))
    h1 = body.add_element(Element.new('h1'))
    h1.text = 'RDocLinkChecker Report'

    add_summary(body)
    add_broken_links(body)
    # add_offsite_links(body) unless onsite_only
    report_file_path = 'Report.htm' # _Not_ .html.
    doc.write(File.new(report_file_path, 'w'), 2)
  end

  def add_summary(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Summary'

    # Parameters table.
    data = []
    [
      :html_dirpath,
      :onsite_only,
      :no_toc
    ].each do |sym|
      value = send(sym).inspect
      row = {sym => :label, value => :good}
      data.push(row)
    end
    table2(body, data, 'parameters', 'Parameters')
    body.add_element(Element.new('p'))

    # Times table.
    elapsed_time = @counts[:end_time] - @counts[:start_time]
    seconds = elapsed_time % 60
    minutes = (elapsed_time / 60) % 60
    hours = (elapsed_time/3600)
    elapsed_time_s = "%2.2d:%2.2d:%2.2d" % [hours, minutes, seconds]
    format = "%Y-%m-%d-%a-%H:%M:%SZ"
    start_time_s = @counts[:start_time].strftime(format)
    end_time_s = @counts[:end_time].strftime(format)
    data = [
      {'Start Time' => :label, start_time_s => :good},
      {'End Time' => :label, end_time_s => :good},
      {'Elapsed Time' => :label, elapsed_time_s => :good},
    ]
    table2(body, data, 'times', 'Times')
    body.add_element(Element.new('p'))

    # Counts.
    data = [
      {'Source Pages' => :label, @counts[:source_pages] => :good},
      {'Target Pages' => :label, @counts[:target_pages] => :good},
      {'Links Checked' => :label, @counts[:links_checked] => :good},
      {'Links Broken' => :label, @counts[:links_broken] => :bad},
    ]
    table2(body, data, 'counts', 'Counts')
    body.add_element(Element.new('p'))

  end

  def add_broken_links(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Broken Links by Source Page'

    if @counts[:links_broken] == 0
      p = body.add_element('p')
      p.text = 'None.'
      return
    end

    # Legend.
    ul = body.add_element(Element.new('ul'))
    li = ul.add_element(Element.new('li'))
    li.text = 'Href: the href of the anchor element.'
    li = ul.add_element(Element.new('li'))
    li.text = 'Text: the text of the anchor element.'
    li = ul.add_element(Element.new('li'))
    li.text = 'Path: the URL or path of the link (not including the fragment):'
    ul2 = li.add_element(Element.new('ul'))
    li2 = ul2.add_element(Element.new('li'))
    li2.text = 'For an on-site link, an abbreviated path is given.'
    li2 = ul2.add_element(Element.new('li'))
    li2.text = <<EOT
For an off-site link, the full URL is given.
If the path is reddish, the page was not found.
EOT
    li = ul.add_element(Element.new('li'))
    li.text = <<EOT
Fragment: the fragment of the link.
If the fragment is reddish, fragment was not found.
EOT

    pages.each_pair do |path, page|
      broken_links = page.links.select {|link| !link.valid_p }
      next if broken_links.empty?

      page_div = body.add_element(Element.new('div'))
      page_div.add_attribute('class', 'broken_page')
      page_div.add_attribute('path', path)
      page_div.add_attribute('count', broken_links.count)
      h3 = page_div.add_element(Element.new('h3'))
      a = Element.new('a')
      a.text = "#{path} (#{broken_links.count})"
      a.add_attribute('href', path)
      h3.add_element(a)

      broken_links.each do |link|
        link_div = page_div.add_element(Element.new('div'))
        link_div.add_attribute('class', 'broken_link')
        data = []
        # Text, URL, fragment
        a = Element.new('a')
        a.text = link.href
        a.add_attribute('href', link.href)
        data.push({'Href' => :label, a => :bad})
        data.push({'Text' => :label, link.text => :good})
        fragment_p = !link.fragment.nil?
        class_ = fragment_p ? :good : :bad
        data.push({'Path' => :label, link.real_path => class_})
        class_ = fragment_p ? :bad : :good
        data.push({'Fragment' => :label, link.fragment => class_})
        if link.exception
          data.push({'Exception' => :label, link.exception.class => :bad})
          data.push({'Message' => :label, link.exception.message => :bad})
        end
        id = link.exception ? 'bad_url' : 'bad_fragment'
        table2(link_div, data, id)
        page_div.add_element(Element.new('p'))
      end
    end

  end

  def add_offsite_links(body)
    h2 = body.add_element(Element.new('h2'))
    h2.text = 'Off-Site Links by Source Page'
    none = true
    pages.each_pair do |path, page|
      offsite_links = page.links.select do |link|
        RDocLinkChecker.offsite?(link.href)
      end
      next if offsite_links.empty?

      none = false
      h3 = body.add_element(Element.new('h3'))
      a = Element.new('a')
      a.text = path
      a.add_attribute('href', path)
      h3.add_element(a)

      offsite_links.each do |link|
        data = []
        # Text, URL, fragment
        a = Element.new('a')
        a.text = link.href
        a.add_attribute('href', link.href)
        class_ = link.valid_p ? :good : :bad
        data.push({'Href' => :label, a => class_})
        data.push({'Text' => :label, link.text => :good})
        table2(body, data)
        body.add_element(Element.new('p'))
      end
    end
    if none
      p = body.add_element(Element.new('p'))
      p.text = 'None.'
    end
  end

  Classes = {
    label: 'label center neutral',
    good: 'data center good',
    iffy: 'data center iffy',
    bad: 'data center bad',
  }

  def table2(parent, data, id, title = nil)
    data = data.dup
    table = parent.add_element(Element.new('table'))
    table.add_attribute('id', id)
    if title
      tr = table.add_element(Element.new('tr)'))
      th = tr.add_element(Element.new('th'))
      th.add_attribute('colspan', 2)
      if title.kind_of?(REXML::Element)
        th.add_element(title)
      else
        th.text = title
      end
    end
    data.each do |row_h|
      label, label_class, value, value_class = row_h.flatten
      tr = table.add_element(Element.new('tr'))
      td = tr.add_element(Element.new('td'))
      td.text = label
      td.add_attribute('class', Classes[label_class])
      td = tr.add_element(Element.new('td'))
      if value.kind_of?(REXML::Element)
        td.add_element(value)
      else
        td.text = value
      end
      td.add_attribute('class', Classes[value_class])
    end
  end

  class Error; end

  class HttpResponseError < Error

    attr_accessor :url, :x

    def initialize(url, x)
      self.url = url
      self.x = x
    end

    def message
      <<EOT
#{self.class.name}:
An exception was raised when checking page availability with Net::HTTP:
  Url: #{url}
  Class: #{x.class}
  Message: #{x.message}
EOT
    end

  end

  class HttpStatusCodeError < Error

    attr_accessor :url, :code

    def initialize(url, code)
      self.url = url
      self.code = code
    end

    def message
      <<EOT
#{self.class.name}:
  The return code for the page was not 200:
    Url: #{url}
    Return code: #{code}
EOT
    end

  end

  # Class to represent a page.
  class Page

    attr_accessor :path, :type, :pages, :counts, :code,
                  :links, :ids, :dirname, :onsite_only, :content_type

    # Returns a new \Page object:
    #
    # - +path+: a path relative to the HTML directory (if on-site)
    #   or a URL (if off-site).
    # - +pages+: hash of path/page pairs.
    # - +counts+: hash of counts.
    #
    def initialize(type, path, onsite_only, pages: {}, counts: {})
      self.path = path
      self.type = type
      self.pages = pages
      self.counts = counts
      self.onsite_only = onsite_only
      self.code = nil
      self.links = []
      self.ids = []
      self.dirname = File.dirname(path)
      self.dirname = self.dirname == '.' ? '' : dirname
    end

    def to_h
      {
        path: path,
        type: type,
        dirname: dirname,
        code: code
      }
    end

    # Gather links for the page:
    #
    # - +doc+: Nokogiri document to be parsed for links.
    #
    def gather_links(doc)
      i = 0
      # The links are in the anchors.
      doc.search('a').each do |a|
        # Ignore pilcrow (paragraph character) and up-arrow.
        next if a.text == "\u00B6"
        next if a.text == "\u2191"

        href = a.attr('href')
        next if href.nil? or href.empty?
        next if RDocLinkChecker.offsite?(href) && onsite_only
        next unless RDocLinkChecker.checkable?(href)

        link = Link.new(href, a.text, dirname)
        next if link.path.nil? || link.path.empty?

        links.push(link)
        i += 1
      end
    end

    # Gather link targets for the page.
    # +doc+ is the Nokogiri document to be parsed.
    def gather_link_targets(doc)
      # Don't do twice (some pages are both source and target).
      return unless ids.empty?

      # For off-site, gather all ids, regardless of element.
      if RDocLinkChecker.offsite?(path)
        doc.xpath("//*[@id]").each do |element|
          id = element.attr('id')
          ids.push(id)
        end
        doc.xpath("//*[@name]").each do |element|
          name = element.attr('name')
          ids.push(name)
        end
        doc.xpath("//a[@href]").each do |element|
          href = element.attr('href')
          next unless href.start_with?('#')
          ids.push(href.sub('#', ''))
        end
        return
      end

      # We're on-site, which means that the page is RDoc-generated
      # and we know what to expect.
      # In theory, an author can link to any element that has an attribute :id.
      # In practice, gathering all such elements is very time-consuming.
      # These are the elements currently linked to:
      #
      # - body
      # - a
      # - div
      # - dt
      # - h*
      #
      # We can add more as needed (i.e., if/when we have actual broken links).

      # body element has 'top', which is a link target.
      body = doc.at('//body')
      id = body.attribute('id')
      ids.push(id) if id

      # Some ids are in the as (anchors).
      body.search('a').each do |a|
        id = a.attr(id)
        ids.push(id) if id
      end

      # Method ids are in divs, but gather only method-detail divs.
      body.search('div').each do |div|
        class_ = div.attr('class')
        next if class_.nil?
        next unless class_.match('method-')
        id = div.attr('id')
        ids.push(id) if id
      end

      # Constant ids are in dts.
      body.search('dt').each do |dt|
        id = dt.attr('id')
        ids.push(id) if id
      end

      # Label ids are in headings.
      %w[h1 h2 h3 h4 h5 h6].each do |tag|
        body.search(tag).each do |h|
          id = h.attr('id')
          ids.push(id) if id
        end
      end
    end

  end

  # Class to represent a link.
  class Link

    attr_accessor :href, :text, :dirname, :path, :fragment, :valid_p, :real_path, :exception

    # Returns a new \Link object:
    #
    # - +href+: attribute href from anchor element.
    # - +text+: attribute text from anchor element.
    # - +dirname+: directory path of the linking page.
    #
    def initialize(href, text, dirname)
      self.href = href
      self.text = text
      self.dirname = dirname
      path, fragment = href.split('#', 2)
      self.path = path
      self.fragment = fragment
      self.valid_p = nil
      self.real_path = make_real_path(dirname, path)
      self.exception = nil
    end

    def to_h
      {
        href: href,
        text: text,
      }
    end

    # Return the real (not relative) path of the link.
    def make_real_path(dirname, path)
      # Trim single dot.
      return path.sub('./', '') if path.start_with?('./')
      return path if dirname.nil? || dirname.empty?

      # May have one or more leading '../'.
      up_dir = '../'
      levels = path.scan(/(?=#{up_dir})/).count
      dirs = dirname.split('/')
      if levels == 0
        dirs.empty? ? path : File.join(dirname, path)
      else
        # Remove leading '../' elements.
        path = path.gsub(%r[\.\./], '')
        # Remove the corresponding parts of dirname.
        dirs.pop(levels)
        return path if dirs.empty?
        dirname = dirs.join('/')
        File.join(dirname, path)
      end
    end

    # Returns whether the link has a fragment.
    def has_fragment?
      fragment ? true : false
    end

    # Puts link info onto $stdout.
    def puts(i)
      $stdout.puts <<EOT
Link #{i}:
  Href:      #{href}
  Text:      #{text}
  Path:      #{path}
  Fragment:  #{fragment}
  Valid:     #{valid_p}
  Real path: #{real_path}
  Dirname:   #{dirname}
EOT
    end
  end

end
