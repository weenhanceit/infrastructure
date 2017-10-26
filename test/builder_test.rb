# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"
require "etc"

class BuildTest < Test
  include TestHelpers
  include Nginx

  def test_save_reverse_proxy_http
    Nginx.chroot("/tmp/test_builder") do
      prepare_fake_files("example.com")

      builder = Nginx::Builder::Base.new(
        "example.com",
        Nginx::ServerBlock.new(
          server: Nginx::Server.new("example.com"),
          listen: Nginx::ListenHttp.new,
          location: Nginx::ReverseProxyLocation.new("http://search.example.com")
        )
      )

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
      assert_no_directory Nginx.root_directory("example.com")
    end
  end

  def test_save_reverse_proxy_https
    Nginx.chroot("/tmp/test_builder") do
      prepare_fake_files("example.com")

      builder = Nginx::Builder::ReverseProxyHttps.new(
        "example.com",
        "http://search.example.com"
      )

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal expected_reverse_proxy_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
      assert_no_directory Nginx.root_directory("example.com")
    end
  end

  def test_save_static_http
    Nginx.chroot("/tmp/builder_test") do
      prepare_fake_files("example.com")

      builder = Nginx::Builder::Site.new(
        "example.com",
        Etc.getlogin,
        Nginx::StaticServerBlock.new(
          server: Nginx::Site.new("example.com", Etc.getlogin),
          listen: Nginx::ListenHttp.new,
          location: Nginx::Location.new("/")
        )
      )

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
      prepare_fake_files("example.com")

      builder = Nginx::Builder::Site.new(
        "example.com",
        Etc.getlogin,
        Nginx::StaticServerBlock.new(
          server: Nginx::Site.new("example.com", Etc.getlogin),
          listen: Nginx::ListenHttps.new("example.com"),
          location: Nginx::Location.new
        ),
        Nginx::TlsRedirectServerBlock.new("example.com")
      )

      assert builder.save, "Failed to save server block"
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_equal expected_https_server_block, builder.to_s
    end
  end
end
