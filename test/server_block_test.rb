# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"
require "etc"

class ServerBlockTest < Test
  include TestHelpers
  include Nginx

  def test_reverse_proxy_http
    server_block = Nginx::ServerBlock.new(
      server: Nginx::Server.new(domain: SharedInfrastructure::Domain.new("search.example.com")),
      listen: Nginx::ListenHttp.new,
      location: [
        Nginx::AcmeLocation.new("example.com"),
        Nginx::ReverseProxyLocation.new("http://10.0.0.1")
      ]
    )
    assert_equal expected_reverse_proxy_http_server_block, server_block.to_s
  end

  def test_reverse_proxy_https
    builder = Nginx::Builder::Base.new(
      Nginx::StaticServerBlock.new(
        server: Nginx::Server.new(domain: SharedInfrastructure::Domain.new("search.example.com")),
        listen: Nginx::ListenHttps.new("search.example.com"),
        location: Nginx::ReverseProxyLocation.new("http://10.0.0.1")
      ),
      Nginx::TlsRedirectServerBlock.new("search.example.com")
    )
    assert_equal expected_reverse_proxy_https_server_block, builder.to_s
  end

  def test_static_http
    server_block = Nginx::StaticServerBlock.new(
      server: Nginx::Site.new(domain: SharedInfrastructure::Domain.new("example.com")),
      listen: Nginx::ListenHttp.new,
      location: Nginx::Location.new("/")
    )
    assert_equal expected_static_http_server_block, server_block.to_s
  end

  def test_static_https
    builder = Nginx::Builder::Site.new(
      Etc.getlogin,
      Nginx::StaticServerBlock.new(
        server: Nginx::Site.new(domain: SharedInfrastructure::Domain.new("example.com")),
        listen: Nginx::ListenHttps.new("example.com"),
        location: Nginx::Location.new
      ),
      Nginx::TlsRedirectServerBlock.new("example.com"),
      domain: SharedInfrastructure::Domain.new("example.com")
    )
    assert_equal expected_https_server_block, builder.to_s
  end
end
