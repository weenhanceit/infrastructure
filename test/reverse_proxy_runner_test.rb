# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class ReverseProxyRunnerTest < Test
  include TestHelpers

  def setup
    ARGV.clear
  end

  def test_one_arg
    assert_output "", "domain and target url required\n" do
      ARGV << "example.com"
      Runner::ReverseProxy.new.main
    end
  end

  def test_reverse_proxy_http
    Nginx.chroot("/tmp/builder_test") do
      prepare_fake_files("example.com")

      ARGV.concat(%w[-d example.com http://search.example.com])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      puts `ls -l #{Nginx.server_block_location("example.com")}`
      assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end
end
