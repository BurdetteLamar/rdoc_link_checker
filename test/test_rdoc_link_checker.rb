# frozen_string_literal: true

require "test_helper"

class TestRDocLinkChecker < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::RDocLinkChecker::VERSION
  end

  def test_parameters_table
    [true, false].each do |onsite_only|
      [true, false].each do |no_toc|
        exp_texts = [
          ['Parameters'],
          ["html_dirpath", "\"test/html\""],
          ['onsite_only', onsite_only.to_s],
          ['no_toc', no_toc.to_s],
        ]
        doc = run_link_checker('test/html', onsite_only, no_toc)
        table = doc.xpath("//table[@id='parameters']")
        table.search('tr').each_with_index do |row, i|
          texts = row.search('th, td').map { |cell| cell.text.strip }
          assert_equal(exp_texts[i], texts)
        end
      end
    end
  end

  def test_times_table
    exp_texts = [
      'Times',
      'Start Time',
      'End Time',
      'Elapsed Time'
    ]
    doc = run_link_checker('test/html')
    table = doc.xpath("//table[@id='times']")
    table.search('tr').each_with_index do |row, i|
      texts = row.search('th, td').map { |cell| cell.text.strip }
      assert_equal(exp_texts[i], texts[0])
      exp = i == 0 ? 1 : 2
      assert_equal(exp, texts.size)
    end
  end

  def test_counts_table
    exp_texts = [
      'Counts',
      'Source Pages',
      'Target Pages',
      'Links Checked',
      'Links Broken'
    ]
    doc = run_link_checker('test/html')
    table = doc.xpath("//table[@id='counts']")
    table.search('tr').each_with_index do |row, i|
      texts = row.search('th, td').map { |cell| cell.text.strip }
      assert_equal(exp_texts[i], texts[0])
      exp = i == 0 ? 1 : 2
      assert_equal(exp, texts.size)
      next if i == 0
      count = Integer(texts[1])
      assert_operator(count, :>=, 0)
    end
  end

  def test_broken_links
    exp_labels = %w[Href Text Path Fragment]
    exp_data = [
      [
        'https://nosuch.xyzzy',
        'nosuch.xyzzy',
        'https://nosuch.xyzzy',\
        '',
        'RDocLinkChecker::HttpResponseError',
        /SocketError/,
      ],
      [
        'https://docs.ruby-lang.org/en/master/Array.html#xyzzy',
        'docs.ruby-lang.org/en/master/Array.html#xyzzy',
        'https://docs.ruby-lang.org/en/master/Array.html',
        'xyzzy'
      ]
    ]
    doc = run_link_checker('test/html')
    page_divs = doc.xpath("//div[@class='broken_page']")
    page_divs.each do |page_div|
      path = page_div.attribute('path').value
      count = Integer(page_div.attribute('count').value)
      # There's a bug in RDoc (fixed but not released)
      # that generates certain bad links on the TOC.
      next if path == 'table_of_contents.html' && count == 6
      link_divs = page_div.search('div')
      link_divs.each_with_index do |link_div, i|
        # First one has just four rows, second has six.
        exp_labels_ = exp_labels
        if i == 0
          exp_labels_ += %w[Exception Message]
        end
        exp_data_ = exp_data[i]
        table = link_div.search('table')[0]
        table.search('tr').each_with_index do |row, j|
          texts = row.search('th, td').map { |cell| cell.text.strip }
          assert_equal(exp_labels_[j], texts[0])
          assert_match(exp_data_[j], texts[1])
          assert_equal(2, texts.size)
        end
      end
    end
    # table = doc.xpath("//table[@id='counts']")
    # table.search('tr').each_with_index do |row, i|

  end

  def run_link_checker(html_dirpath, onsite_only = false, no_toc = false)
    command = "ruby bin/rdoc_link_checker #{html_dirpath}"
    command += ' --onsite_only' if onsite_only
    command += ' --no_toc' if no_toc
    system(command)
    report_path = File.join(html_dirpath, 'Report.htm')
    source_text = File.read(report_path)
    Nokogiri::HTML(source_text)
  end
end
