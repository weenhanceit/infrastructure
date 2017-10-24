# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"
require "etc"

class ServerBlockTest < Test
  include TestHelpers

  def test_reverse_proxy_http
    server_block = Nginx::ServerBlock.new(
      server: Nginx::Server.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::ReverseProxyLocation.new("/", "http://search.example.com")
    )
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK, server_block.to_s
  end

  def test_save_reverse_proxy_http
    server_block = Nginx::ServerBlock.new(
      server: Nginx::Server.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::ReverseProxyLocation.new("/", "http://search.example.com")
    )

    server_block.class.include FakeFiles
    server_block.prepare_fake_files("example.com")

    assert server_block.save, "Failed to save server block"
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-enabled")
    assert_file server_block.server_block_location("example.com")
    assert_file server_block.enabled_server_block_location("example.com")
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
      File.open(server_block.server_block_location("example.com"), "r", &:read)
    assert_no_directory server_block.root_directory("example.com")
  end

  def test_static_http
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::Location.new("/")
    )
    assert_equal EXPECTED_STATIC_HTTP_SERVER_BLOCK, server_block.to_s
  end

  def test_save_static_http
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new("example.com", Etc.getlogin),
      listen: Nginx::ListenHttp.new,
      location: Nginx::Location.new("/")
    )

    server_block.class.include FakeFiles
    server_block.prepare_fake_files("example.com")

    assert server_block.save, "Failed to save server block"
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-enabled")
    assert_file server_block.server_block_location("example.com")
    assert_file server_block.enabled_server_block_location("example.com")
    assert_directory server_block.root_directory("example.com")
    assert_equal EXPECTED_STATIC_HTTP_SERVER_BLOCK, server_block.to_s
  end

  def test_static_https
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new("example.com"),
      listen: Nginx::ListenHttps.new("example.com"),
      location: Nginx::Location.new
    )
    assert_equal EXPECTED_STATIC_HTTPS_SERVER_BLOCK, server_block.to_s
  end

  def test_save_static_https
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new("example.com", Etc.getlogin),
      listen: Nginx::ListenHttps.new("example.com"),
      location: Nginx::Location.new
    )

    server_block.class.include FakeFiles
    server_block.prepare_fake_files("example.com")

    assert server_block.save, "Failed to save server block"
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(server_block.fake_root, "/etc/nginx/sites-enabled")
    assert_file server_block.server_block_location("example.com")
    assert_file server_block.enabled_server_block_location("example.com")
    assert_directory server_block.root_directory("example.com")
    assert_equal EXPECTED_STATIC_HTTPS_SERVER_BLOCK, server_block.to_s
  end
end
