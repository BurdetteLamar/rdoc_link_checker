# frozen_string_literal: true

require_relative 'rdoc_link_checker/version'

class RDocLinkChecker

  def initialize(html_dirpath)
    puts html_dirpath
  end

  class Error < StandardError; end

end
