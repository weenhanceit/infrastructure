# frozen_string_literal: true

class Config
  attr_reader :domain_name, :user

  def certbot_domain_names
    domain_names_array.map { |d| "-d " + d }.join(" ")
  end

  def certificate_directory
    "/etc/letsencrypt/lib/#{domain_name}"
  end

  def domain_names
    domain_names_array.join(" ")
  end

  def initialize(domain_name, user: "ubuntu")
    @domain_name = domain_name
    @user = user
  end

  def root_directory
    "/var/www/#{domain_name}/html"
  end

  def server_block_location
    "/etc/nginx/sites-available/#{domain_name}"
  end

  private

  def domain_names_array
    [domain_name, "www." + domain_name]
  end
end
