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
      Nginx.prepare_fake_files("example.com")

      ARGV.concat(%w[example.com http://search.example.com])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_reverse_proxy_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")

      ARGV.concat(%w[-p HTTPS --dhparam 128 example.com http://search.example.com])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_reverse_proxy_https_when_files_exist
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")

      key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "fullchain.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "chain.pem")]
      FileUtils.mkdir_p Nginx.certificate_directory("example.com")
      FileUtils.touch(key_file_list)

      ARGV.concat(%w[-d --dhparam 128 example.com http://search.example.com])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end
end
