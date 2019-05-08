# frozen_string_literal: true

module SharedInfrastructure
  class Domain
    def available_site
      "/etc/nginx/sites-available/#{domain_name}"
    end

    def certbot_domain_names
      domain_names.map { |domain| "#{domain} www.#{domain}" }.join(" ")
    end

    def certificate_directory
      "/etc/letsencrypt/live/#{domain_name}"
    end

    def domain_name
      domain_names.first
    end

    def enabled_site
      "/etc/nginx/sites-enabled/#{domain_name}"
    end

    def initialize(domain_names)
      domain_names = [domain_names] unless domain_names.respond_to?(:map)
      @domain_names = domain_names
    end

    def rails_env_log(rails_env = "production")
      "/var/www/#{domain_name}/log/#{rails_env}.log"
    end

    def root
      "/var/www/#{domain_name}"
    end

    # TODO: Remove this if not needed.
    def secrets
      File.join(site_root, "secrets")
    end

    def site_root
      File.join(root, "html")
    end

    attr_reader :domain_names
  end
end
