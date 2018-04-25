# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class OutputTest < Test
  include TestHelpers
  include SharedInfrastructure::OutputHelpers

  def test_indent
    assert_equal "  a\n\n  b", indent("a\n\nb")
  end

  def test_indent_by_first_line
    assert_equal "    a\n\n  b", indent("  a\n\nb")
  end

  def test_indent_by_first_line_second_already_indented
    assert_equal "    a\n\n    b", indent("  a\n\n  b")
  end

  def test_indent_by_first_line_amount
    assert_equal "   a\n\n   b", indent("  a\n\n  b", 1)
  end

  def test_file_names
    o = SharedInfrastructure::Output.new("example.com")
    assert_equal "example.com", o.path
  end

  def test_fake_file_names
    SharedInfrastructure::Output.fake_root("/tmp")
    o = SharedInfrastructure::Output.open("/var/www/example.com", "w")
    assert_equal "/tmp/var/www/example.com", o.path
    SharedInfrastructure::Output.fake_root(nil)
  end

  def test_fake_file_names_block
    SharedInfrastructure::Output.fake_root("/tmp") do
      o = SharedInfrastructure::Output.new("/var/www/example.com", "w")
      assert_equal "/tmp/var/www/example.com", o.path
    end
    o = SharedInfrastructure::Output.open("example.com")
    assert_equal "example.com", o.path
  end

  def tear_down
    SharedInfrastructure::Output.fake_root(nil)
  end
end
