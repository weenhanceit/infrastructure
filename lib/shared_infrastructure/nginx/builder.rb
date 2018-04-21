# frozen_string_literal: true

module Nginx
  ##
  # Builders.
  # Builders build different files.
  module Builder
    module Https
      def save
        pem_file = "#{Nginx.certificate_directory(certificate_domain)}/dhparam.pem"
        # FileUtils.mkdir_p File.dirname(pem_file)
        `openssl dhparam #{Nginx.dhparam} -out #{pem_file}`
        super
      end
    end

    class Base
      def https_reminder_message
        puts %(You have to obtain a certificate and enable TLS for the site.
To do so, reload the Nginx configuration:

sudo nginx -s reload

Then run the following command:

sudo certbot certonly --webroot -w #{Nginx.root_directory(domain_name)} #{Nginx.certbot_domain_names(domain_name)}

You can test renewal with:

sudo certbot renew --dry-run

Finally, re-run this script to configure nginx for TLS.
)
      end

      def initialize(domain_name, *server_blocks, domain: nil)
        # puts "Base#initialize domain_name: #{domain_name}"
        # puts "Base#initialize server_blocks.inspect: #{server_blocks.inspect}"
        @server_blocks = server_blocks
        @domain_name = domain_name
      end

      def save
        puts "writing server block: #{Nginx.server_block_location(domain_name)}" if Runner.debug
        File.open(Nginx.server_block_location(domain_name), "w") do |f|
          f << to_s
        end
        puts "enabling site" if Runner.debug
        `ln -fs ../sites-available/#{domain_name} #{Nginx.enabled_server_block_location(domain_name)}`
      end

      def to_s
        server_blocks.map(&:to_s).join("\n")
      end

      attr_reader :domain_name, :server_blocks
    end

    class ReverseProxyHttp < Base
      def initialize(domain_name, proxy_url, certificate_domain = nil, domain: nil)
        super(domain_name,
          Nginx::ServerBlock.new(
            server: Nginx::Server.new(domain_name, domain: SharedInfrastructure::Domain.new(domain_name)),
            listen: Nginx::ListenHttp.new,
            location: [
              # TODO: the following should really only happen when the domains
              # are different.
              Nginx::AcmeLocation.new(certificate_domain || domain_name),
              Nginx::ReverseProxyLocation.new(proxy_url)
            ]
          )
        )
      end

      def save
        result = super
        https_reminder_message
        result
      end
    end

    class ReverseProxyHttps < Base
      include Https

      def initialize(domain_name, proxy_url, certificate_domain = nil, domain: nil)
        @certificate_domain = certificate_domain || domain_name

        super(domain_name,
          Nginx::ServerBlock.new(
            server: Nginx::Server.new(domain_name, domain: SharedInfrastructure::Domain.new(domain_name)),
            listen: Nginx::ListenHttps.new(domain_name, certificate_domain),
            location: Nginx::ReverseProxyLocation.new(proxy_url)
          ),
          Nginx::TlsRedirectServerBlock.new(domain_name)
        )
      end

      attr_reader :certificate_domain
    end

    class Site < Base
      def initialize(domain_name, user, *server_blocks, domain: nil)
        super(domain_name, *server_blocks, domain: domain)
        @user = user
      end

      def save
        FileUtils.mkdir_p(Nginx.root_directory(domain_name))
        if Process.uid.zero?
          FileUtils.chown(user,
            "www-data",
            Nginx.root_directory(domain_name))
        end
        super
      end

      attr_reader :user
    end

    class SiteHttp < Site
      def initialize(domain_name, user, _certificate_domain = nil, domain: nil)
        super(domain_name,
          user,
          Nginx::StaticServerBlock.new(
            server: Nginx::Site.new(domain_name, user),
            listen: Nginx::ListenHttp.new,
            location: Nginx::Location.new
          ),
          domain: domain
        )
      end

      def save
        result = super
        https_reminder_message
        result
      end
    end

    class SiteHttps < Site
      include Https

      def initialize(domain_name, user, certificate_domain = nil, domain: nil)
        @certificate_domain = certificate_domain || domain_name

        super(domain_name,
          user,
          Nginx::StaticServerBlock.new(
            server: Nginx::Site.new(domain_name, user),
            listen: Nginx::ListenHttps.new(domain_name, certificate_domain),
            location: Nginx::Location.new
          ),
          Nginx::TlsRedirectServerBlock.new(domain_name),
          domain: domain
        )
      end

      attr_reader :certificate_domain
    end

    class RailsHttp < Site
      def initialize(domain_name, user, _certificate_domain = nil, accel_location: nil, domain: nil)
        accel_location = Accel.new(accel_location, domain: domain) if accel_location
        super(domain_name,
          user,
            Nginx::RailsServerBlock.new(
              upstream: Nginx::Upstream.new(domain_name),
              server: Nginx::RailsServer.new(domain: domain),
              listen: Nginx::ListenHttp.new,
              location: [
                Nginx::RailsLocation.new(domain_name),
                accel_location ? Nginx::AccelLocation.new(domain_name, accel_location) : nil,
                Nginx::ActionCableLocation.new(domain_name)
              ].compact,
              accel_location: accel_location,
              domain: domain
            )
          )
      end

      def save
        Systemd::Rails.write_unit_file(domain_name) && super
      end
    end

    class RailsHttps < Site
      include Https

      def initialize(domain_name, user, certificate_domain = nil, accel_location: nil, domain: nil)
        @certificate_domain = certificate_domain || domain_name
        accel_location = Accel.new(accel_location, domain) if accel_location
        super(domain_name,
          user,
          Nginx::RailsServerBlock.new(
            upstream: Nginx::Upstream.new(domain_name),
            server: Nginx::RailsServer.new(domain: domain),
            listen: Nginx::ListenHttps.new(domain_name, certificate_domain),
            location: [
              Nginx::RailsLocation.new(domain_name),
              accel_location ? Nginx::AccelLocation.new(domain_name, accel_location) : nil,
              Nginx::ActionCableLocation.new(domain_name)
            ].compact,
            accel_location: accel_location,
            domain: domain
          ),
          Nginx::TlsRedirectServerBlock.new(domain_name)
        )
      end

      # FIXME: DRY this up with the HTTP class.
      def save
        Systemd::Rails.write_unit_file(domain_name) && super
      end

      attr_reader :certificate_domain
    end
  end
end
