# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"
require "etc"

class BuilderTest < Test
  include TestHelpers
  include Nginx

  def setup
    FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_save_rails_http
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      ENV["SECRET_KEY_BASE"] = "BASE"
      ENV["DATABASE_USERNAME"] = "USER"
      ENV["DATABASE_PASSWORD"] = "PASS"
      ENV["EMAIL_PASSWORD"] = "EMAIL"

      builder = Nginx::Builder::RailsHttp.new("example.com", Etc.getlogin)

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_equal expected_rails_http_server_block, builder.to_s
      assert_file Systemd.unit_file("example.com")
    end
  end

  def test_save_rails_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.dhparam = 128
      Nginx.prepare_fake_files("example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      ENV["SECRET_KEY_BASE"] = "BASE"
      ENV["DATABASE_USERNAME"] = "USER"
      ENV["DATABASE_PASSWORD"] = "PASS"
      ENV["EMAIL_PASSWORD"] = "EMAIL"

      builder = Nginx::Builder::RailsHttps.new("example.com", Etc.getlogin)

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_rails_https_server_block, builder.to_s
      assert_file Systemd.unit_file("example.com")
    end
  end

  def test_save_reverse_proxy_http
    Nginx.chroot("/tmp/test_builder") do
      Nginx.prepare_fake_files("search.example.com")

      builder = Nginx::Builder::Base.new(
        "search.example.com",
        Nginx::ServerBlock.new(
          server: Nginx::Server.new("search.example.com"),
          listen: Nginx::ListenHttp.new,
          location: Nginx::ReverseProxyLocation.new("http://10.0.0.1")
        )
      )

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
      assert_no_directory Nginx.root_directory("search.example.com")
    end
  end

  def test_save_reverse_proxy_https
    Nginx.chroot("/tmp/test_builder") do
      Nginx.dhparam = 128
      Nginx.prepare_fake_files("search.example.com")

      builder = Nginx::Builder::ReverseProxyHttps.new(
        "search.example.com",
        "http://10.0.0.1"
      )

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_directory Nginx.certificate_directory("search.example.com")
      assert_file File.join(Nginx.certificate_directory("search.example.com"), "dhparam.pem")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
      assert_no_directory Nginx.root_directory("search.example.com")
    end
  end

  def test_save_static_http
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")

      builder = Nginx::Builder::SiteHttp.new("example.com", Etc.getlogin)

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_equal expected_static_http_server_block, builder.to_s
    end
  end

  def test_save_static_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")
      Nginx.dhparam = 128

      builder = Nginx::Builder::SiteHttps.new("example.com", Etc.getlogin)

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_https_server_block, builder.to_s
    end
  end
end
