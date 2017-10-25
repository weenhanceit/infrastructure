# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "config_mock"
require "test"

class ReverseProxyBuilderTest < Test
  include FileUtils
  include TestHelpers

  def setup
    FileUtils.rm_rf ConfigMock.fake_root, secure: true
    ARGV.clear
  end

  def test_one_arg
    assert_output "", "domain and target url required\n" do
      ARGV << "example.com"
      ReverseProxyBuilder.new.main
    end
  end

  def test_domain
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
    Nginx.chroot("/tmp/builder_test") do
      ARGV.concat %w[example.com search.example.com]
      builder = ReverseProxyBuilder.new.main(config_class: ConfigMock)
      assert builder.build, "Build failed"
      assert_no_directory builder.root_directory
      assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
      assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
      assert_file builder.server_block_location
    end
  end

  def test_reverse_proxy_http
    Nginx.chroot("/tmp/builder_test") do
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
  end

  def enabled_server_block_location(builder)
    File.join(builder.fake_root,
      "/etc/nginx/sites-enabled",
      File.basename(builder.server_block_location))
  end
end
