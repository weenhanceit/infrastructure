module SharedInfrastructure
  class Domain
    def available_site
      "/etc/nginx/sites-available/#{domain_name}"
    end

    def certbot_domain_names
      "#{domain_name} www.#{domain_name}"
    end

    def certificate_directory
      "/etc/letsencrypt/live/#{domain_name}"
    end

    def enabled_site
      "/etc/nginx/sites-enabled/#{domain_name}"
    end

    def initialize(domain_name)
      @domain_name = domain_name
    end

    def production_log
      "/var/www/#{domain_name}/log/production.log"
    end

    def secrets
      File.join(site_root, "secrets")
    end

    def site_root
      "/var/www/#{domain_name}/html"
    end

    attr_reader :domain_name
  end
end
