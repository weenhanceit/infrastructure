# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "config_mock"

class ReverseProxyBuilderTest < MiniTest::Test
  include FileUtils

  def setup
    FileUtils.rm_rf ConfigMock.fake_root, secure: true
  end

  def test_one_arg
    assert_output "", "domain and target url required\n" do
      ARGV.clear
      ARGV << "example.com"
      ReverseProxyBuilder.new.main
    end
  end

  def test_domain
    ARGV.clear
    ARGV.concat %w[example.com search.example.com]
    builder = ReverseProxyBuilder.new.main
    assert_equal "-d example.com -d www.example.com", builder.certbot_domain_names
    assert_equal "/etc/letsencrypt/live/example.com", builder.certificate_directory
    assert_equal "example.com", builder.domain_name
    assert_equal "example.com www.example.com", builder.domain_names
    assert_equal "/var/www/example.com/html", builder.root_directory
    assert_equal "/etc/nginx/sites-available/example.com", builder.server_block_location
    assert_equal "ubuntu", builder.user
  end

  def test_build_http
    ARGV.clear
    ARGV.concat %w[example.com search.example.com]
    builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
    assert builder.build, "Build failed"
    assert_no_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
  end

  # def test_build_https
  #   ARGV.clear
  #   ARGV.concat(%w[-p HTTPS --dhparam 128 example.com search.example.com])
  #   builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
  #   assert builder.build, "Build failed"
  #   assert_directory builder.certificate_directory
  #   assert_directory builder.root_directory
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
  #   assert_file builder.server_block_location
  #   assert_equal EXPECTED_HTTPS_SERVER_BLOCK,
  #     File.open(builder.server_block_location, "r", &:read)
  #   assert_file File.join(builder.certificate_directory, "dhparam.pem")
  #   # The following is actually done by the letsencrypt stuff, so we don't
  #   # need to test it.
  #   # assert_file File.join(builder.certificate_directory, "privkey.pem")
  #   # assert_file File.join(builder.certificate_directory, "fullchain.pem")
  # end

  # def test_default_to_https_when_keys_exist
  #   ARGV.clear
  #   ARGV.concat %w[example.com search.example.com]
  #   builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
  #   key_file_list = [File.join(builder.certificate_directory, "privkey.pem"),
  #                    File.join(builder.certificate_directory, "fullchain.pem")]
  #   FileUtils.touch(key_file_list)
  #   ARGV.clear
  #   ARGV.concat(%w[--dhparam 128 example.com])
  #   # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
  #   # puts key_file_list
  #   builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
  #   # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
  #   assert builder.build, "Build failed"
  #   assert_directory builder.certificate_directory
  #   assert_directory builder.root_directory
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
  #   assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
  #   assert_file builder.server_block_location
  #   assert_equal EXPECTED_HTTPS_SERVER_BLOCK,
  #     File.open(builder.server_block_location, "r", &:read)
  #   assert_file File.join(builder.certificate_directory, "dhparam.pem")
  # end

  def test_reverse_proxy_http
    ARGV.clear
    ARGV.concat(%w[example.com http://search.example.com])
    builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
    assert builder.build, "Build failed"
    assert_no_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
    assert_file enabled_server_block_location(builder)
    assert_equal EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK,
      File.open(builder.server_block_location, "r", &:read)
  end

  def assert_directory(d)
    assert File.directory?(d), "#{d}: does not exist"
  end

  def assert_file(f)
    assert File.exist?(f), "#{f}: does not exist"
  end

  def assert_no_directory(d)
    assert !File.directory?(d), "#{d} should not exist"
  end

  def enabled_server_block_location(builder)
    File.join(builder.fake_root,
      "/etc/nginx/sites-enabled",
      File.basename(builder.server_block_location))
  end

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
