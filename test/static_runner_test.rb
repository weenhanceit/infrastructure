# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class StaticRunnerTest < Test
  include TestHelpers

  def setup
    ARGV.clear
    ::FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_one_arg
    assert_raises Runner::MissingArgument do
      assert_output "", "domain required\n" do
        Runner::StaticSite.new.main
      end
    end
  end

  def test_static_http
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")

        ARGV.concat(%w[example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/example.com"
        # puts "DOMAIN ROOT STAT: #{File.stat('/tmp/builder_test/var/www/example.com').mode.to_s(8)}"
        assert_equal 0o2000, File.stat("/tmp/builder_test/var/www/example.com").mode & 0o2000
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file "/tmp/builder_test/etc/nginx/sites-available/example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/example.com"
        assert_equal expected_static_http_server_block,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end

  def test_static_https
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")

        ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/example.com"
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file "/tmp/builder_test/etc/nginx/sites-available/example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/example.com"
        assert_directory "/tmp/builder_test/etc/letsencrypt/live/example.com"
        assert_file "/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem"
        assert_equal expected_https_server_block,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end

  def test_static_https_when_files_exist
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")

        key_file_list = [File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "privkey.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "fullchain.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "chain.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "cert.pem")]
        FileUtils.touch(key_file_list)

        ARGV.concat(%w[--dhparam 128 example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/example.com"
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file "/tmp/builder_test/etc/nginx/sites-available/example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/example.com"
        assert_directory "/tmp/builder_test/etc/letsencrypt/live/example.com"
        assert_file "/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem"
        assert_equal expected_https_server_block,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/example.com", "r", &:read)
      end
    end
  end

  def test_static_https_with_certificate_directory_arg
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com")

        ARGV.concat(%w[-p HTTPS --dhparam 128 -c example.com search.example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/search.example.com"
        assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"

        assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
        assert_directory "/tmp/builder_test/etc/letsencrypt/live/example.com"
        assert_file "/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem"
        assert_equal expected_https_server_block_certificate_domain,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
      end
    end
  end

  def test_static_https_when_files_exist_with_certificate_directory_arg
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com", "example.com")
        FileUtils.mkdir_p "/tmp/builder_test/etc/letsencrypt/live/example.com"

        key_file_list = [File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "privkey.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "fullchain.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "chain.pem"),
                         File.join("/tmp/builder_test/etc/letsencrypt/live/example.com", "cert.pem")]
        FileUtils.touch(key_file_list)

        ARGV.concat(%w[--dhparam 128 -c example.com search.example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/search.example.com"
        assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"

        assert_file "/tmp/builder_test/etc/nginx/sites-available/search.example.com"
        assert_file "/tmp/builder_test/etc/nginx/sites-enabled/search.example.com"
        assert_directory "/tmp/builder_test/etc/letsencrypt/live/example.com"
        assert_file "/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem"
        assert_equal expected_https_server_block_certificate_domain,
                     File.open("/tmp/builder_test/etc/nginx/sites-available/search.example.com", "r", &:read)
      end
    end
  end
end
