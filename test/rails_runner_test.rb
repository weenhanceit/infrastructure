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
    fake_env
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      ARGV.concat(%w[example.com])
      runner = Runner::Rails.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal expected_rails_http_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_rails_https
    fake_env
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
      runner = Runner::Rails.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_rails_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_rails_https_when_files_exist
    fake_env
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "fullchain.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "chain.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "cert.pem")]
      FileUtils.touch(key_file_list)

      ARGV.concat(%w[--dhparam 128 example.com])
      runner = Runner::Rails.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_rails_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_rails_https_with_certificate_directory_arg
    fake_env
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      ARGV.concat(%w[-p HTTPS --dhparam 128 -c example.com search.example.com])
      runner = Runner::Rails.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("search.example.com")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_directory Nginx.certificate_directory("example.com")
      # Since the idea here is that the certificate is already generated,
      # don't check for the `dhparam.pem` file here
      # assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_rails_https_server_block_certificate_domain,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
    end
  end

  def test_rails_https_when_files_exist_with_certificate_directory_arg
    fake_env
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("search.example.com", "example.com")
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

      key_file_list = [File.join(Nginx.certificate_directory("example.com"), "privkey.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "fullchain.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "chain.pem"),
                       File.join(Nginx.certificate_directory("example.com"), "cert.pem")]
      FileUtils.touch(key_file_list)

      ARGV.concat(%w[--dhparam 128 -c example.com search.example.com])
      runner = Runner::Rails.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("search.example.com")
      assert_file Nginx.server_block_location("search.example.com")
      assert_file Nginx.enabled_server_block_location("search.example.com")
      assert_directory Nginx.certificate_directory("example.com")
      # Since the idea here is that the certificate is already generated,
      # don't check for the `dhparam.pem` file here
      # assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_rails_https_server_block_certificate_domain,
        File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
    end
  end
end
