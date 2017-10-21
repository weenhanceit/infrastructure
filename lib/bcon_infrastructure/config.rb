# frozen_string_literal: true

class Config
  attr_reader :domain_name, :proxy_url, :user

  def certbot_domain_names
    domain_names_array.map { |d| "-d " + d }.join(" ")
  end

  def certificate_directory
    "/etc/letsencrypt/live/#{domain_name}"
  end

  def domain_names
    domain_names_array.join(" ")
  end

  def enable_site
    `ln -fs ../sites-available/#{domain_name} #{enabled_server_block_location}`
  end

  def enabled_server_block_location
    File.join NGINX_ROOT, "/sites-enabled", domain_name
  end

  def initialize(domain_name, user: "ubuntu", proxy_url: nil)
    @domain_name = domain_name
    @user = user
    @proxy_url = proxy_url
  end

  def make_certificate_directory
    FileUtils.mkdir_p(certificate_directory)
  end

  def make_website_root
    FileUtils.mkdir_p(root_directory)
  end

  def root_directory
    "/var/www/#{domain_name}/html"
  end

  def server_block_location
    File.join NGINX_ROOT, "/sites-available", domain_name
  end

  private

  def domain_names_array
    [domain_name, "www." + domain_name]
  end

  NGINX_ROOT = "/etc/nginx"
end
