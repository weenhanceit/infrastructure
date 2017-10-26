# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class StaticRunnerTest < Test
  include TestHelpers

  def setup
    ARGV.clear
    ::FileUtils.rm_rf "/tmp/builder_test", secure: true
  end

  def test_one_arg
    assert_output "", "domain required\n" do
      Runner::StaticSite.new.main
    end
  end

  def test_static_http
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")

      ARGV.concat(%w[example.com])
      runner = Runner::StaticSite.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_equal expected_static_http_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_static_https
    Nginx.chroot("/tmp/builder_test") do
      Nginx.prepare_fake_files("example.com")

      ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
      runner = Runner::StaticSite.new.main
      assert runner.save, "Build failed"
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end

  def test_static_https_when_files_exist
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
      assert_directory Nginx.root_directory("example.com")
      assert_file Nginx.server_block_location("example.com")
      assert_file Nginx.enabled_server_block_location("example.com")
      assert_directory Nginx.certificate_directory("example.com")
      assert_file File.join(Nginx.certificate_directory("example.com"), "dhparam.pem")
      assert_equal expected_https_server_block,
        File.open(Nginx.server_block_location("example.com"), "r", &:read)
    end
  end
end
