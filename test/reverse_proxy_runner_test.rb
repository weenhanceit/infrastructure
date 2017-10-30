# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class ReverseProxyRunnerTest < Test
  include TestHelpers

  def setup
    ARGV.clear
    ::FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_one_arg
    assert_output "", "domain and target url required\n" do
      ARGV << "search.example.com"
      Runner::ReverseProxy.new.main
    end
  end

  def test_reverse_proxy_http
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      ARGV.concat(%w[search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("search.example.com")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
    end
  end

  def test_reverse_proxy_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      ARGV.concat(%w[-p HTTPS --dhparam 128 search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("search.example.com")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_directory Nginx.certificate_directory("search.example.com")
      assert_file File.join(Nginx.certificate_directory("search.example.com"), "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
    end
  end

  def test_reverse_proxy_https_when_files_exist
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      key_file_list = [File.join(Nginx.certificate_directory("search.example.com"), "privkey.pem"),
                       File.join(Nginx.certificate_directory("search.example.com"), "fullchain.pem"),
                       File.join(Nginx.certificate_directory("search.example.com"), "chain.pem"),
                       File.join(Nginx.certificate_directory("search.example.com"), "cert.pem")]
      FileUtils.touch(key_file_list)

      ARGV.concat(%w[--dhparam 128 search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory Nginx.root_directory("search.example.com")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_directory Nginx.certificate_directory("search.example.com")
      assert_file File.join(Nginx.certificate_directory("search.example.com"), "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
    end
  end
end
