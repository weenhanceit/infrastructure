require "minitest/autorun"
require "bcon_infrastructure"

class ConfigTest < Minitest::Test
  def setup
    @config = Config.new("example.com")
  end

  def test_certbot_domain_names
    assert_equal "-d example.com -d www.example.com", @config.certbot_domain_names
  end

  def test_certificate_directory
    assert_equal "/etc/letsencrypt/live/example.com", @config.certificate_directory
  end

  def test_domain_name
    assert_equal "example.com", @config.domain_name
  end

  def test_domain_names
    assert_equal "example.com www.example.com", @config.domain_names
  end

  def test_root_directory
    assert_equal "/var/www/example.com/html", @config.root_directory
  end

  def test_server_block_location
    assert_equal "/etc/nginx/sites-available/example.com", @config.server_block_location
  end

  def test_user_default
    assert_equal "ubuntu", @config.user
  end

  def test_user
    config = Config.new("example.com", user: "reid")
    assert_equal "reid", config.user
  end
end
