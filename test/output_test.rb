# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class OutputTest < Test
  include TestHelpers

  def setup
    @o = SharedInfrastructure::Output::Output.new(StringIO.new)
  end
  attr_reader :o

  def test_indent
    assert_equal "  a\n\n  b", o.indent("a\n\nb")
  end

  def test_indent_by_first_line
    assert_equal "    a\n\n  b", o.indent("  a\n\nb")
  end

  def test_indent_by_first_line_second_already_indented
    assert_equal "    a\n\n    b", o.indent("  a\n\n  b")
  end

  def test_indent_by_first_line_amount
    assert_equal "   a\n\n   b", o.indent("  a\n\n  b", 1)
  end

  def test_print
    o.print(o.indent("a\n\nb"))
    o.send(:io).string
    assert_equal "  a\n\n  b", o.send(:io).string
  end

  def test_file_names
    o = SharedInfrastructure::Output::Output.new("example.com")
    assert_equal "example.com", o.send(:io).path
  end

  def test_fake_file_names
    SharedInfrastructure::Output.fake_root("/tmp")
    o = SharedInfrastructure::Output::Output.new("/var/www/example.com")
    assert_equal "/tmp/var/www/example.com", o.send(:io).path
    SharedInfrastructure::Output.fake_root(nil)
  end

  def test_fake_file_names_block
    SharedInfrastructure::Output.fake_root("/tmp") do
      o = SharedInfrastructure::Output::Output.new("/var/www/example.com")
      assert_equal "/tmp/var/www/example.com", o.send(:io).path
    end
    o = SharedInfrastructure::Output::Output.new("example.com")
    assert_equal "example.com", o.send(:io).path
  end
end
