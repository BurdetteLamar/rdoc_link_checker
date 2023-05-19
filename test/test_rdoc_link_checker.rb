# frozen_string_literal: true

require "test_helper"

class TestRDocLinkChecker < Minitest::Test

  def before_run
    puts 'Boo!'
  end

  def test_that_it_has_a_version_number
    refute_nil ::RDocLinkChecker::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end
