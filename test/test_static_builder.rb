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
      StaticBuilder.new.main([])
    end
  end

  def test_domain
    builder = StaticBuilder.new.main(["example.com"])
    assert_equal "-d example.com -d www.example.com", builder.certbot_domain_names
    assert_equal "/etc/letsencrypt/lib/example.com", builder.certificate_directory
    assert_equal "example.com", builder.domain_name
    assert_equal "example.com www.example.com", builder.domain_names
    assert_equal "/var/www/example.com/html", builder.root_directory
    assert_equal "/etc/nginx/sites-available/example.com", builder.server_block_location
    assert_equal "ubuntu", builder.user
  end

  def test_mock
    builder = StaticBuilder.new.main(["example.com"], config_class: ConfigMock)
    assert_match %r{/tmp/.*/etc/letsencrypt/lib/example.com}, builder.certificate_directory
    assert_match %r{/tmp/.*/var/www/example.com/html}, builder.root_directory
    assert_match %r{/tmp/.*/etc/nginx/sites-available/example.com}, builder.server_block_location
  end

  def test_build_http
    builder = StaticBuilder.new.main(["example.com"], config_class: ConfigMock)
    assert builder.build, "Build failed"
    # assert_directory builder.certificate_directory
    assert_directory builder.root_directory
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-available")
    assert_directory File.join(builder.fake_root, "/etc/nginx/sites-enabled")
    assert_file builder.server_block_location
  end

  def assert_directory(d)
    assert File.directory?(d), "#{d}: does not exist"
  end

  def assert_file(f)
    assert File.exist?(f), "#{f}: does not exist"
  end
end
