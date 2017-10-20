module BconInfrastructure
  ##
  # File and directory paths for building infrastructure
  module Files
    def certificate_directory(domain_name)
      "/etc/letsencrypt/live/#{domain_name}"
    end

    def root_directory(domain_name)
      "/var/www/#{domain_name}/html"
    end

    def server_block_location(domain_name)
      "/etc/nginx/sites-available/#{domain_name}"
    end
  end
end
