# frozen_string_literal: true

module Runner
  ##
  # Generate reverse proxy config files for Nginx.
  class ReverseProxy < Base
    def options_for_config(options)
      super(options).merge(proxy_url: ARGV[1])
    end

    def process_args
      $stderr.puts "domain and target url required" unless ARGV.size == 2
      {
        domain_name: ARGV[0],
        proxy_url: ARGV[1]
      }
    end

    def process_options
      super do |opts|
        opts.on("-c DOMAIN",
          "--certificate-domain DOMAIN",
          "Use the certificate for DOMAIN.") do |certificate_domain|
          options[:certificate_domain] = certificate_domain
        end
      end
    end

    def protocol_factory(options)
      Nginx::Builder::Base.new(
        options[:domain_name],
        Nginx::ServerBlock.new(
          server: Nginx::Server.new(options[:domain_name]),
          listen: Nginx::ListenHttp.new,
          location: Nginx::ReverseProxyLocation.new(options[:proxy_url])
        )
      )
    end
  end
end
