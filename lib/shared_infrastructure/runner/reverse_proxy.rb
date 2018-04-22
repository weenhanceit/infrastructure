# frozen_string_literal: true

module Runner
  ##
  # Generate reverse proxy config files for Nginx.
  class ReverseProxy < Base
    def options_for_config(options)
      super(options).merge(proxy_url: ARGV[1])
    end

    def process_args(opts = nil)
      raise MissingArgument.new("domain and target url required", opts) unless ARGV.size == 2
      {
        domain_name: ARGV[0],
        proxy_url: ARGV[1]
      }
    end

    def process_options
      super(Nginx::Builder::ReverseProxyHttp, Nginx::Builder::ReverseProxyHttps)
    end

    def protocol_factory(options)
      protocol_class = super(
        options,
        Nginx::Builder::ReverseProxyHttp,
        Nginx::Builder::ReverseProxyHttps
      )

      domain_name = options.delete(:domain_name)
      proxy_url = options.delete(:proxy_url)
      certificate_domain = options.delete(:certificate_domain)
      domain = SharedInfrastructure::Domain.new(domain_name)
      protocol_class.new(proxy_url, certificate_domain, domain: domain)
    end
  end
end
