require "minitest/autorun"
require "bcon_infrastructure"

class StaticHttpBuilderTest < Minitest::Test
  def test_http_server_block
    builder = StaticHttpBuilder.new(HttpServerBlock, Config.new("example.com"))
    assert_equal %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  listen 80;
  listen [::]:80;

  location / {
    try_files $uri $uri/ =404;
  }
}
), builder.server_block
  end
end
