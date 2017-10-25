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
    ARGV.clear
  end

  def test_no_args
    assert_output "", "domain required\n" do
      StaticBuilder.new.main
    end
  end

  def test_domain
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

  def test_build_http
    Nginx.chroot("/tmp/builder_test") do
      ARGV << "example.com"
      builder = StaticBuilder.new.main(config_class: ConfigMock)
      assert builder.build, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
    end
  end

  def test_build_https
    Nginx.chroot("/tmp/builder_test") do
      StaticBuilder.include TestHelpers

      ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
      builder = StaticBuilder.new.main(config_class: ConfigMock)
      assert builder.build, "Build failed"
      assert_directory Nginx.certificate_directory("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal expected_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      # The following is actually done by the letsencrypt stuff, so we don't
      # need to test it.
      # assert_file File.join(builder.certificate_directory, "privkey.pem")
      # assert_file File.join(builder.certificate_directory, "fullchain.pem")
    end
  end

  def test_default_to_https_when_keys_exist
    Nginx.chroot("/tmp/builder_test") do
      StaticBuilder.include TestHelpers

      ARGV.concat(%w[example.com])
      builder = StaticBuilder.new.main(config_class: ConfigMock)
      key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "fullchain.pem")]
      builder.send(:config).make_certificate_directory
      FileUtils.touch(key_file_list)
      ARGV.clear
      ARGV.concat(%w[--dhparam 128 example.com])
      # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
      # puts key_file_list
      builder = StaticBuilder.new.main(config_class: ConfigMock)
      # puts "KEYS SHOULD EXIST #{key_file_list.all? { |f| File.exist?(f) }}"
      assert builder.build, "Build failed"
      assert_directory Nginx.certificate_directory("example.com")
      assert_directory Nginx.root_directory("example.com")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-available")
      assert_directory File.join(Nginx.root, "/etc/nginx/sites-enabled")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal expected_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
    end
  end

  EXPECTED_HTTPS_REDIRECT_SERVER_BLOCK = %(
server {
  server_name example.com www.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
end
