# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class RailsRunnerTest < Test
  include TestHelpers

  def setup
    ARGV.clear
    ::FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_one_arg
    assert_raises Runner::MissingArgument do
      assert_output "", "domain required\n" do
        Runner::Rails.new.main
      end
    end
  end

  def test_rails_http
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_no_directory("/tmp/builder_test/var/www/example.com/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_server_block,
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
        assert_equal expected_unit_file, File.open("/tmp/builder_test/lib/systemd/system/example.com.service", &:read)
        assert_equal expected_rails_logrotate_conf, File.open(SharedInfrastructure::Output.file_name("/etc/logrotate.d/example.com.conf"), &:read)
      end
    end
  end

  def test_rails_http_two_domains
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.ca")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.ca")))

        ARGV.concat(%w[example.ca example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.ca")
        assert_no_directory("/tmp/builder_test/var/www/example.ca/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.ca")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.ca")

        assert_equal expected_rails_http_server_block("example.ca", "example.com"),
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.ca", "r", &:read)
        assert_equal expected_unit_file(domain: "example.ca"), File.open("/tmp/builder_test/lib/systemd/system/example.ca.service", &:read)
        assert_equal expected_rails_logrotate_conf(domain: "example.ca"), File.open(SharedInfrastructure::Output.file_name("/etc/logrotate.d/example.ca.conf"), &:read)
      end
    end
  end

  def test_rails_env_local
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[--rails-env local example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_server_block,
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
        assert_equal expected_rails_logrotate_conf("local"), File.open(SharedInfrastructure::Output.file_name("/etc/logrotate.d/example.com.conf"), &:read)
        assert_equal expected_unit_file("local"), File.open("/tmp/builder_test/lib/systemd/system/example.com.service", &:read)
      end
    end
  end

  def test_rails_https
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_no_directory("/tmp/builder_test/var/www/example.com/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block,
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end

  def test_rails_https_two_domains
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.ca")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.ca")))

        ARGV.concat(%w[-p HTTPS --dhparam 128 example.ca example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.ca")
        assert_no_directory("/tmp/builder_test/var/www/example.ca/html")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.ca")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.ca")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.ca")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.ca/dhparam.pem")

        assert_equal expected_rails_https_server_block("example.ca", "example.com"),
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.ca", "r", &:read)
      end
    end
  end

  def test_rails_https_when_files_exist
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        FileUtils.touch(key_file_list("example.com"))

        ARGV.concat(%w[--dhparam 128 example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block,
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end

  def test_rails_https_with_certificate_directory_arg
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[-p HTTPS --dhparam 128 -c example.com search.example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/search.example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        # Since the idea here is that the certificate is already generated,
        # don't check for the `dhparam.pem` file here
        # assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block_certificate_domain,
          File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
      end
    end
  end

  def test_rails_https_when_files_exist_with_certificate_directory_arg
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com", "example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        FileUtils.touch(key_file_list("example.com"))

        ARGV.concat(%w[--dhparam 128 -c example.com search.example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/search.example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        # Since the idea here is that the certificate is already generated,
        # don't check for the `dhparam.pem` file here
        # assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block_certificate_domain,
          File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
      end
    end
  end

  def test_rails_http_x_accel
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[--accel releases example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_x_accel_server_block,
          File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end
end
