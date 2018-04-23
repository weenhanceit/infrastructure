# frozen_string_literal: true

module Nginx
  ##
  # Builders.
  # Builders build different files.
  module Builder
    module Https
      def save
        pem_file = "#{Nginx.certificate_directory(certificate_domain)}/dhparam.pem"
        FileUtils.mkdir_p File.dirname(pem_file)
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

sudo certbot certonly --webroot -w #{Nginx.root_directory(domain.domain_name)} #{Nginx.certbot_domain_names(domain.domain_name)}

You can test renewal with:

sudo certbot renew --dry-run

Finally, re-run this script to configure nginx for TLS.
)
      end

      def initialize(*server_blocks, domain: nil)
        # puts "Base#initialize domain_name: #{domain_name}"
        # puts "Base#initialize server_blocks.inspect: #{server_blocks.inspect}"
        @server_blocks = server_blocks
        @domain = domain
      end

      def save
        puts "writing server block: #{Nginx.server_block_location(domain.domain_name)}" if Runner.debug
        File.open(Nginx.server_block_location(domain.domain_name), "w") do |f|
          f << to_s
        end
        puts "enabling site" if Runner.debug
        `ln -fs ../sites-available/#{domain.domain_name} #{Nginx.enabled_server_block_location(domain.domain_name)}`
      end

      def to_s
        server_blocks.map(&:to_s).join("\n")
      end

      attr_reader :domain, :server_blocks
    end

    class ReverseProxyHttp < Base
      def initialize(proxy_url, certificate_domain = nil, domain: nil)
        super(Nginx::ServerBlock.new(
          server: Nginx::Server.new(domain: domain),
          listen: Nginx::ListenHttp.new,
          location: [
            # TODO: the following should really only happen when the domains
            # are different.
            Nginx::AcmeLocation.new(certificate_domain || domain.domain_name),
            Nginx::ReverseProxyLocation.new(proxy_url)
          ]
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

    class ReverseProxyHttps < Base
      include Https

      def initialize(proxy_url, certificate_domain = nil, domain: nil)
        @certificate_domain = certificate_domain || domain.domain_name

        super(Nginx::ServerBlock.new(
          server: Nginx::Server.new(domain: domain),
          listen: Nginx::ListenHttps.new(domain.domain_name, certificate_domain),
          location: Nginx::ReverseProxyLocation.new(proxy_url)
        ),
          Nginx::TlsRedirectServerBlock.new(domain.domain_name),
          domain: domain
        )
      end

      attr_reader :certificate_domain
    end

    class Site < Base
      def initialize(user, *server_blocks, domain: nil)
        super(*server_blocks, domain: domain)
        @user = user
      end

      def save
        FileUtils.mkdir_p(Nginx.root_directory(domain.domain_name))
        if Process.uid.zero?
          FileUtils.chown(user,
            "www-data",
            Nginx.root_directory(domain.domain_name))
        end
        super
      end

      attr_reader :user
    end

    class SiteHttp < Site
      def initialize(user, _certificate_domain = nil, domain: nil)
        super(user,
          Nginx::StaticServerBlock.new(
            server: Nginx::StaticServer.new(domain: domain),
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

      def initialize(user, certificate_domain = nil, domain: nil)
        @certificate_domain = certificate_domain || domain.domain_name

        super(user,
          Nginx::StaticServerBlock.new(
            server: Nginx::StaticServer.new(domain: domain),
            listen: Nginx::ListenHttps.new(domain.domain_name, certificate_domain),
            location: Nginx::Location.new
          ),
          Nginx::TlsRedirectServerBlock.new(domain.domain_name),
          domain: domain
        )
      end

      attr_reader :certificate_domain
    end

    class Rails < Site
      def save
        env = {}
        %w[SECRET_KEY_BASE
           DATABASE_USERNAME
           DATABASE_PASSWORD
           EMAIL_PASSWORD].each do |var|
          env[var.to_sym] = if ENV[var].nil?
                              puts "Enter #{var}: "
                              $stdin.gets.strip
                            else
                              ENV[var]
                            end
        end
        File.open(SharedInfrastructure::Output.file_name(File.join(domain.site_root, "secrets")), "w", 0o600) do |io|
          io << env.map { |pair| "#{pair[0]}=#{pair[1]}\n" }.join
        end &&
          Systemd::Rails.write_unit_file(domain.domain_name, domain) &&
          super
      end
    end

    class RailsHttp < Rails
      def initialize(user, _certificate_domain = nil, accel_location: nil, domain: nil)
        accel_location = Accel.new(accel_location, domain: domain) if accel_location
        super(user,
            Nginx::RailsServerBlock.new(
              upstream: Nginx::Upstream.new(domain.domain_name),
              server: Nginx::RailsServer.new(domain: domain),
              listen: Nginx::ListenHttp.new,
              location: [
                Nginx::RailsLocation.new(domain.domain_name),
                accel_location ? Nginx::AccelLocation.new(domain.domain_name, accel_location) : nil,
                Nginx::ActionCableLocation.new(domain.domain_name)
              ].compact,
              accel_location: accel_location,
              domain: domain
            ),
            domain: domain
          )
      end
    end

    class RailsHttps < Rails
      include Https

      def initialize(user, certificate_domain = nil, accel_location: nil, domain: nil)
        @certificate_domain = certificate_domain || domain.domain_name
        accel_location = Accel.new(accel_location, domain) if accel_location
        super(user,
          Nginx::RailsServerBlock.new(
            upstream: Nginx::Upstream.new(domain.domain_name),
            server: Nginx::RailsServer.new(domain: domain),
            listen: Nginx::ListenHttps.new(domain.domain_name, certificate_domain),
            location: [
              Nginx::RailsLocation.new(domain.domain_name),
              accel_location ? Nginx::AccelLocation.new(domain.domain_name, accel_location) : nil,
              Nginx::ActionCableLocation.new(domain.domain_name)
            ].compact,
            accel_location: accel_location,
            domain: domain
          ),
          Nginx::TlsRedirectServerBlock.new(domain.domain_name),
          domain: domain
        )
      end

      attr_reader :certificate_domain
    end
  end
end
