# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"
require "etc"

class ServerBlockTest < Test
  include TestHelpers
  include Nginx

  def test_reverse_proxy_http
    server_block = Nginx::ServerBlock.new(
      server: Nginx::Server.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::ReverseProxyLocation.new("http://search.example.com")
    )
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK, server_block.to_s
  end

  def test_reverse_proxy_https
    builder = Nginx::Builder.new(
      "example.com",
      Nginx::StaticServerBlock.new(
        server: Nginx::Server.new("example.com"),
        listen: Nginx::ListenHttps.new("example.com"),
        location: Nginx::ReverseProxyLocation.new("http://search.example.com")
      ),
      Nginx::TlsRedirectServerBlock.new("example.com")
    )
    assert_equal expected_reverse_proxy_https_server_block, builder.to_s
  end

  def test_static_http
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new("example.com"),
      listen: Nginx::ListenHttp.new,
      location: Nginx::Location.new("/")
    )
    assert_equal expected_static_http_server_block, server_block.to_s
  end

  def test_static_https
    builder = Nginx::SiteBuilder.new(
      "example.com",
      Etc.getlogin,
      Nginx::StaticServerBlock.new(
        server: Nginx::Site.new("example.com", Etc.getlogin),
        listen: Nginx::ListenHttps.new("example.com"),
        location: Nginx::Location.new
      ),
      Nginx::TlsRedirectServerBlock.new("example.com")
    )
    assert_equal expected_https_server_block, builder.to_s
  end
end
