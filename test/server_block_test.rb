# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

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
end
