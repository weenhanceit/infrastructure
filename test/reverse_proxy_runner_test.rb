# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class ServerBlockTest < Test
  include TestHelpers

  def setup
    ARGV.clear
  end

  def test_one_arg
    assert_output "", "domain and target url required\n" do
      ARGV << "example.com"
      ReverseProxy.new.main
    end
  end

  def test_reverse_proxy_http
    ARGV.concat(%w[example.com http://search.example.com])
    runner = ReverseProxy.new.main
    assert runner.build, "Build failed"
    assert_no_directory runner.server_block.root_directory("example.com")
    assert_file runner.server_block.server_block_location("example.com")
    assert_file enabled_server_block_location("example.com")
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
      File.open(runner.server_block.server_block_location("example.com"), "r", &:read)
  end
end
