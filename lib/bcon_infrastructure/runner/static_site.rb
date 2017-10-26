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
      user = options.delete(:user) || "ubuntu"
      certificate_domain = options.delete(:certificate_domain)
      protocol_class.new(domain_name, user, certificate_domain)
    end
  end
end
