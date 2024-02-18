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
    assert_raises Runner::MissingArgument do
      ARGV << "search.example.com"
      Runner::ReverseProxy.new.main
    end
  end

  def test_reverse_proxy_http
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      ARGV.concat(%w[-c example.com search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"
      assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
      assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
      assert_equal expected_reverse_proxy_http_server_block,
        File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
    end
  end

  def test_reverse_proxy_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      ARGV.concat(%w[-p HTTPS --dhparam 128 search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"
      assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
      assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
      assert_directory "/tmp/builder_test/etc/letsencrypt/live/search.example.com"
      assert_file File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
    end
  end

  def test_reverse_proxy_https_when_files_exist
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")

      key_file_list = [File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "privkey.pem"),
                       File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "fullchain.pem"),
                       File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "chain.pem"),
                       File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "cert.pem")]
      FileUtils.touch(key_file_list)

      ARGV.concat(%w[--dhparam 128 search.example.com http://10.0.0.1])
      runner = Runner::ReverseProxy.new.main
      assert runner.save, "Build failed"
      assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"
      assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
      assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
      assert_directory "/tmp/builder_test/etc/letsencrypt/live/search.example.com"
      assert_file File.join("/tmp/builder_test/etc/letsencrypt/live/search.example.com", "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
    end
  end
end
