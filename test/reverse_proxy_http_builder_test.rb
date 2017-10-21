require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class ReverseProxyHttpBuilderTest < Test
  def test_http_reverse_proxy
    builder = ReverseProxyHttpBuilder.new(ReverseProxyHttpServerBlock,
      Config.new("example.com", proxy_url: "http://search.example.com"))
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK, builder.server_block
  end
end
