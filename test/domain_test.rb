# frozen_string_literal: true

require "minitest/autorun"
require "shared_infrastructure"
require "test"

class DomainTest < Test
  include TestHelpers

  def setup
    @o = SharedInfrastructure::Domain.new("example.com")
  end
  attr_reader :o

  def test_file_names
    assert_equal "/var/www/example.com/html", o.site_root
    assert_equal "/etc/letsencrypt/live/example.com", o.certificate_directory
    assert_equal "/etc/nginx/sites-available/example.com", o.available_site
    assert_equal "/etc/nginx/sites-enabled/example.com", o.enabled_site
    assert_equal "example.com www.example.com", o.certbot_domain_names
  end

  def test_fake_file_names
    SharedInfrastructure::Output.fake_root("/tmp") do
      assert_equal "/var/www/example.com/html", o.site_root
      assert_equal "/etc/letsencrypt/live/example.com", o.certificate_directory
      assert_equal "/etc/nginx/sites-available/example.com", o.available_site
      assert_equal "/etc/nginx/sites-enabled/example.com", o.enabled_site
      assert_equal "example.com www.example.com", o.certbot_domain_names
    end
  end
end
