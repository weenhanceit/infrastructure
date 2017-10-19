require "minitest/autorun"
require "bcon_infrastructure"

class ReverseProxyHttpBuilderTest < Minitest::Test
  def test_http_reverse_proxy
    builder = ReverseProxyHttpBuilder.new(ReverseProxyHttpServerBlock, Config.new("example.com"))
    assert_equal %(server {
  server_name example.com www.example.com;

  listen 80;
  listen [::]:80;

  location @example.com {
    proxy_pass http://search.example.com;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  }
}
), builder.server_block
  end
end
