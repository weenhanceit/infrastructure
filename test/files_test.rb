require "minitest/autorun"
require "bcon_infrastructure"

class FilesTest < Minitest::Test
  include BconInfrastructure::Files

  def test_certificate_directory
    assert_equal "/etc/letsencrypt/live/example.com", certificate_directory("example.com")
  end

  def test_root_directory
    assert_equal "/var/www/example.com/html", root_directory("example.com")
  end

  def test_server_block_location
    assert_equal "/etc/nginx/sites-available/example.com", server_block_location("example.com")
  end
end
