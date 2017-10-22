# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "config_mock"
require "test"

class StaticBuilderTest < Test
  include FileUtils
  include TestHelpers

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
    assert_match "/tmp/builder_test/etc/letsencrypt/live/example.com", builder.certificate_directory
    assert_match "/tmp/builder_test/var/www/example.com/html", builder.root_directory
    assert_match "/tmp/builder_test/etc/nginx/sites-available/example.com", builder.server_block_location
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
    assert_file enabled_server_block_location(builder)
  end

  def test_build_https
    StaticBuilder.include TestHelpers

    ARGV.clear
    ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    assert builder.build, "Build failed"
    assert_directory builder.certificate_directory
    assert_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
    assert_file enabled_server_block_location(builder)
    assert_equal builder.expected_https_server_block + EXPECTED_HTTPS_REDIRECT_SERVER_BLOCK,
      File.open(builder.server_block_location, "r", &:read)
    assert_file File.join(builder.certificate_directory, "dhparam.pem")
    # The following is actually done by the letsencrypt stuff, so we don't
    # need to test it.
    # assert_file File.join(builder.certificate_directory, "privkey.pem")
    # assert_file File.join(builder.certificate_directory, "fullchain.pem")
  end

  def test_default_to_https_when_keys_exist
    StaticBuilder.include TestHelpers

    ARGV.clear
    ARGV.concat(%w[example.com])
    builder = StaticBuilder.new.main(config_class: ConfigMock)
    key_file_list = [File.join(builder.certificate_directory, "privkey.pem"),
                     File.join(builder.certificate_directory, "fullchain.pem")]
    builder.send(:config).make_certificate_directory
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
    assert_file enabled_server_block_location(builder)
    assert_equal builder.expected_https_server_block + EXPECTED_HTTPS_REDIRECT_SERVER_BLOCK,
      File.open(builder.server_block_location, "r", &:read)
    assert_file File.join(builder.certificate_directory, "dhparam.pem")
  end

  def enabled_server_block_location(builder)
    File.join(builder.fake_root,
      "/etc/nginx/sites-enabled",
      File.basename(builder.server_block_location))
  end

  EXPECTED_HTTPS_REDIRECT_SERVER_BLOCK = %(
server {
  server_name example.com www.example.com ;
  listen 80;
  listen [::]:80;
  return 301 https://$server_name/$request_uri;
}
)
end
