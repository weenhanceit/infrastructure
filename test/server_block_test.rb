# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class ServerBlockTest < Test
  def test_reverse_proxy_http
    server_block = Nginx::ServerBlock.new(
      server: Nginx::Server.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::ReverseProxyLocation.new("/", "http://search.example.com")
    )
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK, server_block.to_s
  end
end
