# frozen_string_literal: true

module Runner
  ##
  # Generate static site config files for Nginx.
  class StaticSite < Base
    def protocol_factory(options)
      protocol_class = super(
        options,
        Nginx::Builder::SiteHttp,
        Nginx::Builder::SiteHttps
      )

      domain_name = options.delete(:domain_name)
      user = options.delete(:user)
      certificate_domain = options.delete(:certificate_domain)
      domain = SharedInfrastructure::Domain.new(domain_name)
      protocol_class.new(user, certificate_domain, domain: domain)
    end
  end
end
