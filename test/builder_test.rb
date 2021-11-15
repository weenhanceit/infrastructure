# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"
require "etc"

class BuilderTest < Test
  include TestHelpers
  include Nginx

  def setup
    FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_save_rails_http
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        builder = Nginx::Builder::RailsHttp.new(Etc.getlogin, domain: SharedInfrastructure::Domain.new("example.com"))

        assert builder.save, "Failed to save server block"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_no_directory("/tmp/builder_test/var/www/example.com/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_server_block, builder.to_s
        assert_file Systemd.unit_file("example.com")
      end
    end
  end

  def test_save_rails_https
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.dhparam = 128
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        builder = Nginx::Builder::RailsHttps.new(Etc.getlogin, domain: SharedInfrastructure::Domain.new("example.com"))

        assert builder.save, "Failed to save server block"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_no_directory("/tmp/builder_test/var/www/example.com/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block, builder.to_s
        assert_file Systemd.unit_file("example.com")
      end
    end
  end

  def test_save_reverse_proxy_http
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com")

        builder = Nginx::Builder::Base.new(
          Nginx::ServerBlock.new(
            server: Nginx::Server.new(domain: SharedInfrastructure::Domain.new("search.example.com")),
            listen: Nginx::ListenHttp.new,
            location: [
              Nginx::AcmeLocation.new("example.com"),
              Nginx::ReverseProxyLocation.new("http://10.0.0.1")
            ]
          ),
          domain: SharedInfrastructure::Domain.new("search.example.com")
        )

        assert builder.save, "Failed to save server block"
        assert_directory "/tmp/builder_test/etc/nginx/sites-available"
        assert_directory "/tmp/builder_test/etc/nginx/sites-enabled"
        assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
        assert_equal expected_reverse_proxy_http_server_block,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
        assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"
      end
    end
  end

  def test_save_reverse_proxy_https
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.dhparam = 128
        Nginx.prepare_fake_files("search.example.com")

        builder = Nginx::Builder::ReverseProxyHttps.new(
          "http://10.0.0.1",
          domain: SharedInfrastructure::Domain.new("search.example.com")
        )

        assert builder.save, "Failed to save server block"
        assert_directory "/tmp/builder_test/etc/nginx/sites-available"
        assert_directory "/tmp/builder_test/etc/nginx/sites-enabled"
        assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
        assert_directory "/tmp/builder_test/etc/letsencrypt/live/search.example.com"
        assert_file "/tmp/builder_test/etc/letsencrypt/live/search.example.com/dhparam.pem"
        assert_equal expected_reverse_proxy_https_server_block,
                     File.open("/tmp/builder_test/etc/nginx/sites-enabled/search.example.com", "r", &:read)
        assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"
      end
    end
  end

  def test_save_static_http
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")

        builder = Nginx::Builder::SiteHttp.new(Etc.getlogin, domain: SharedInfrastructure::Domain.new("example.com"))

        assert builder.save, "Failed to save server block"
        assert_directory "/tmp/builder_test/etc/nginx/sites-available"
        assert_directory "/tmp/builder_test/etc/nginx/sites-enabled"
        assert_file "/tmp/builder_test/etc/nginx/sites-available/example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/example.com"

        assert_directory "/tmp/builder_test/var/www/example.com"
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_equal expected_static_http_server_block, builder.to_s
      end
    end
  end

  def test_save_static_https
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        Nginx.dhparam = 128

        builder = Nginx::Builder::SiteHttps.new(Etc.getlogin, domain: SharedInfrastructure::Domain.new("example.com"))

        assert builder.save, "Failed to save server block"
        assert_directory "/tmp/builder_test/etc/nginx/sites-available"
        assert_directory "/tmp/builder_test/etc/nginx/sites-enabled"
        assert_file "/tmp/builder_test/etc/nginx/sites-available/example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/example.com"

        assert_directory "/tmp/builder_test/var/www/example.com"
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file "/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem"
        assert_equal expected_https_server_block, builder.to_s
      end
    end
  end
end
