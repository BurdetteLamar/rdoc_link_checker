# frozen_string_literal: true

require "test_helper"

class TestRDocLinkChecker < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::RDocLinkChecker::VERSION
  end

  def test_parameters
    [true, false].each do |onsite_only|
      [true, false].each do |no_toc|
        doc = run_link_checker('test/html', onsite_only, no_toc)
        rows = doc.at('table').search('tr')
        row = rows.shift
        texts = row.search('th, td').map { |cell| cell.text.strip }
        assert_equal('Parameters', row.text.strip)
        row = rows.shift
        texts = row.search('th, td').map { |cell| cell.text.strip }
        assert_equal(["html_dirpath", "\"test/html\""], texts)
        row = rows.shift
        texts = row.search('th, td').map { |cell| cell.text.strip }
        assert_equal(['onsite_only', onsite_only.to_s], texts)
        row = rows.shift
        texts = row.search('th, td').map { |cell| cell.text.strip }
        assert_equal(['no_toc', no_toc.to_s], texts)
      end
    end

  end

  def run_link_checker(html_dirpath, onsite_only, no_toc)
    command = "ruby bin/rdoc_link_checker #{html_dirpath}"
    command += ' --onsite_only' if onsite_only
    command += ' --no_toc' if no_toc
    system(command)
    report_path = File.join(html_dirpath, 'Report.htm')
    source_text = File.read(report_path)
    Nokogiri::HTML(source_text)
  end
end
