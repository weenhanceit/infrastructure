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
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file Nginx.server_block_location("example.com")
        assert_file Nginx.enabled_server_block_location("example.com")
        assert_equal expected_static_http_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
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

        assert_file Nginx.server_block_location("example.com")
        assert_file Nginx.enabled_server_block_location("example.com")
        assert_directory Nginx.certificate_directory("example.com")
        assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
        assert_equal expected_https_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
      end
    end
  end

  def test_static_https_when_files_exist
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")

        key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "fullchain.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "chain.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "cert.pem")]
        FileUtils.touch(key_file_list)

        ARGV.concat(%w[--dhparam 128 example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/example.com"
        assert_no_directory "/tmp/builder_test/var/www/example.com/html"

        assert_file Nginx.server_block_location("example.com")
        assert_file Nginx.enabled_server_block_location("example.com")
        assert_directory Nginx.certificate_directory("example.com")
        assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
        assert_equal expected_https_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
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

        assert_file Nginx.server_block_location("search.example.com")
        assert_file Nginx.enabled_server_block_location("search.example.com")
        assert_directory Nginx.certificate_directory("example.com")
        assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
        assert_equal expected_https_server_block_certificate_domain,
          File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
      end
    end
  end

  def test_static_https_when_files_exist_with_certificate_directory_arg
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("search.example.com", "example.com")
        FileUtils.mkdir_p Nginx.certificate_directory("example.com")

        key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "fullchain.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "chain.pem"),
                         File.join(Nginx.certificate_directory("example.com"), "cert.pem")]
        FileUtils.touch(key_file_list)

        ARGV.concat(%w[--dhparam 128 -c example.com search.example.com])
        runner = Runner::StaticSite.new.main
        assert runner.save, "Build failed"

        assert_directory "/tmp/builder_test/var/www/search.example.com"
        assert_no_directory "/tmp/builder_test/var/www/search.example.com/html"

        assert_file Nginx.server_block_location("search.example.com")
        assert_file Nginx.enabled_server_block_location("search.example.com")
        assert_directory Nginx.certificate_directory("example.com")
        assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
        assert_equal expected_https_server_block_certificate_domain,
          File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
      end
    end
  end
end
