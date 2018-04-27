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
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
        assert_equal expected_unit_file, File.open("/tmp/builder_test/lib/systemd/system/example.com.service", &:read)
        assert_equal expected_rails_logrotate_conf, File.open(SharedInfrastructure::Output.file_name("/etc/logrotate.d/example.com.conf"), &:read)
      end
    end
  end

  def test_rails_env_local
    fake_env
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
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
        assert_equal expected_unit_file("local"), File.open("/tmp/builder_test/lib/systemd/system/example.com.service", &:read)
        assert_equal expected_rails_logrotate_conf("local"), File.open(SharedInfrastructure::Output.file_name("/etc/logrotate.d/example.com.conf"), &:read)
      end
    end
  end

  def test_rails_http_secrets_from_stdin
    ENV.delete("SECRET_KEY_BASE")
    ENV.delete("DATABASE_USERNAME")
    ENV.delete("DATABASE_PASSWORD")
    ENV.delete("EMAIL_PASSWORD")

    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[example.com])
        runner = Runner::Rails.new.main
        $stdin = StringIO.open "my_SECRET_KEY_BASE\n" \
                               "my_DATABASE_USERNAME\n" \
                               "my_DATABASE_PASSWORD\n" \
                               "my_EMAIL_PASSWORD\n"
        assert runner.save, "Build failed"
        $stdin = STDIN
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
        expected = "SECRET_KEY_BASE=my_SECRET_KEY_BASE\n" \
                   "DATABASE_USERNAME=my_DATABASE_USERNAME\n" \
                   "DATABASE_PASSWORD=my_DATABASE_PASSWORD\n" \
                   "EMAIL_PASSWORD=my_EMAIL_PASSWORD\n"
        assert_equal expected, File.open(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).read
      end
    end
  end

  def test_rails_https
    fake_env
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[-p HTTPS --dhparam 128 example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
      end
    end
  end

  def test_rails_https_when_files_exist
    fake_env
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
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

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
      end
    end
  end

  def test_rails_https_with_certificate_directory_arg
    fake_env
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
          File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/search.example.com/html/secrets")).mode & 0o7777
      end
    end
  end

  def test_rails_https_when_files_exist_with_certificate_directory_arg
    fake_env
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
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

        assert_directory("/tmp/builder_test/var/www/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/search.example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/search.example.com")
        assert_directory("/tmp/builder_test/etc/letsencrypt/live/example.com")
        # Since the idea here is that the certificate is already generated,
        # don't check for the `dhparam.pem` file here
        # assert_file("/tmp/builder_test/etc/letsencrypt/live/example.com/dhparam.pem")

        assert_equal expected_rails_https_server_block_certificate_domain,
          File.open(Nginx.server_block_location("search.example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/search.example.com/html/secrets")).mode & 0o7777
      end
    end
  end

  def test_rails_http_x_accel
    fake_env
    SharedInfrastructure::Output.fake_root("/tmp/builder_test") do
      Nginx.chroot("/tmp/builder_test") do
        Nginx.prepare_fake_files("example.com")
        FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com")))

        ARGV.concat(%w[--accel /private example.com])
        runner = Runner::Rails.new.main
        assert runner.save, "Build failed"

        assert_directory("/tmp/builder_test/var/www/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-available/example.com")
        assert_file("/tmp/builder_test/etc/nginx/sites-enabled/example.com")

        assert_equal expected_rails_http_x_accel_server_block,
          File.open(Nginx.server_block_location("example.com"), "r", &:read)
        assert_equal 0o600, File.stat(SharedInfrastructure::Output.file_name("/var/www/example.com/html/secrets")).mode & 0o7777
      end
    end
  end
end
