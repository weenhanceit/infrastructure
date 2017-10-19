# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "config_mock"

class StaticBuilderTest < MiniTest::Test
  include FileUtils

  def setup
    FileUtils.rm_rf ConfigMock.fake_root, secure: true
  end

  def test_no_args
    assert_output "", "domain required\n" do
      ARGV.clear
      StaticBuilder.new.main
    end
  end

  def test_domain
    ARGV.clear
    ARGV << "example.com"
    builder = StaticBuilder.new.main
    assert_equal "-d example.com -d www.example.com", builder.certbot_domain_names
    assert_equal "/etc/letsencrypt/live/example.com", builder.certificate_directory
    assert_equal "example.com", builder.domain_name
    assert_equal "example.com www.example.com", builder.domain_names
    assert_equal "/var/www/example.com/html", builder.root_directory
    assert_equal "/etc/nginx/sites-available/example.com", builder.server_block_location
    assert_equal "ubuntu", builder.user
  end

  def test_mock
    ARGV.clear
    ARGV << "example.com"
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    assert_match %r{/tmp/.*/etc/letsencrypt/live/example.com}, builder.certificate_directory
    assert_match %r{/tmp/.*/var/www/example.com/html}, builder.root_directory
    assert_match %r{/tmp/.*/etc/nginx/sites-available/example.com}, builder.server_block_location
  end

  def test_build_http
    ARGV.clear
    ARGV << "example.com"
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    assert builder.build, "Build failed"
    assert_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
  end

  def test_build_https
    ARGV.clear
    ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    assert builder.build, "Build failed"
    assert_directory builder.certificate_directory
    assert_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
    assert_equal EXPECTED_HTTPS_SERVER_BLOCK,
      File.open(builder.server_block_location, "r", &:read)
    assert_file File.join(builder.certificate_directory, "dhparam.pem")
    # The following is actually done by the letsencrypt stuff, so we don't
    # need to test it.
    # assert_file File.join(builder.certificate_directory, "privkey.pem")
    # assert_file File.join(builder.certificate_directory, "fullchain.pem")
  end

  def test_default_to_https_when_keys_exist
    ARGV.clear
    ARGV.concat(%w[example.com])
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    key_file_list = [File.join(builder.certificate_directory, "privkey.pem"),
                     File.join(builder.certificate_directory, "fullchain.pem")]
    FileUtils.touch(key_file_list)
    ARGV.clear
    ARGV.concat(%w[--dhparam 128 example.com])
    # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
    # puts key_file_list
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
    assert builder.build, "Build failed"
    assert_directory builder.certificate_directory
    assert_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
    assert_equal EXPECTED_HTTPS_SERVER_BLOCK,
      File.open(builder.server_block_location, "r", &:read)
    assert_file File.join(builder.certificate_directory, "dhparam.pem")
  end

  # def test_reverse_proxy_http
  #   ARGV.clear
  #   ARGV.concat(%w[-r http://search.example.com example.com])
  #   builder = StaticBuilder.new.main(config_class: ConfigMock)
  #   assert builder.build, "Build failed"
  #   assert_directory builder.root_directory
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
  #   assert_file builder.server_block_location
  #   assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
  #     File.open(builder.server_block_location, "r", &:read)
  # end

  def assert_directory(d)
    assert File.directory?(d), "#{d}: does not exist"
  end

  def assert_file(f)
    assert File.exist?(f), "#{f}: does not exist"
  end

  EXPECTED_HTTPS_SERVER_BLOCK = %(server {
  server_name example.com www.example.com;

  root #{ConfigMock.fake_root}/var/www/example.com/html;
  index index.html index.htm;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam /etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    try_files $uri $uri/ =404;
  }
}

server {
  server_name example.com www.example.com ;
  listen 80;
  listen [::]:80;
  return 301 https://$server_name/$request_uri;
}
)

  EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK = %(server {
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
)
end
