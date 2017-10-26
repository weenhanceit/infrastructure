# frozen_string_literal: true

module Nginx
  module Builder
    module Https
      def save
        `openssl dhparam #{Nginx.dhparam} -out #{Nginx.certificate_directory(domain_name)}/dhparam.pem`
        super
      end
    end

    class Base
      def initialize(domain_name, *server_blocks)
        @server_blocks = server_blocks
        @domain_name = domain_name
      end

      def save
        File.open(Nginx.server_block_location(domain_name), "w") do |f|
          f << to_s
        end
        `ln -fs ../sites-available/#{domain_name} #{Nginx.enabled_server_block_location(domain_name)}`
      end

      def to_s
        server_blocks.map(&:to_s).join("\n")
      end

      attr_reader :domain_name, :server_blocks
    end

    class ReverseProxyHttp < Base
      def initialize(domain_name, proxy_url)
        super(domain_name,
          Nginx::ServerBlock.new(
            server: Nginx::Server.new(domain_name),
            listen: Nginx::ListenHttp.new,
            location: Nginx::ReverseProxyLocation.new(proxy_url)
          )
        )
      end
    end

    class ReverseProxyHttps < Base
      include Https

      def initialize(domain_name, proxy_url)
        super(domain_name,
          Nginx::ServerBlock.new(
            server: Nginx::Server.new(domain_name),
            listen: Nginx::ListenHttps.new(domain_name),
            location: Nginx::ReverseProxyLocation.new(proxy_url)
          ),
          Nginx::TlsRedirectServerBlock.new(domain_name)
        )
      end
    end

    class Site < Base
      def initialize(domain_name, user, *server_blocks)
        super(domain_name, *server_blocks)
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
      def initialize(domain_name, user)
        super(domain_name,
          user,
          Nginx::StaticServerBlock.new(
            server: Nginx::Site.new(domain_name, user),
            listen: Nginx::ListenHttp.new,
            location: Nginx::Location.new
          )
        )
      end
    end

    class SiteHttps < Site
      include Https
      def initialize(domain_name, user)
        super(domain_name,
          user,
          Nginx::StaticServerBlock.new(
            server: Nginx::Site.new(domain_name, user),
            listen: Nginx::ListenHttps.new(domain_name),
            location: Nginx::Location.new
          ),
          Nginx::TlsRedirectServerBlock.new(domain_name)
        )
      end
    end
  end
end