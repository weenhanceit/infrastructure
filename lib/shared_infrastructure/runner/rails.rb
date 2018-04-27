module Runner
  class Rails < Base
    def main
      builder = super
      FileUtils.mkdir_p(File.dirname(Systemd.unit_file("example.com"))) if Nginx.root?
      builder
    end

    def process_options
      super(Nginx::Builder::RailsHttp, Nginx::Builder::RailsHttps)
    end

    def protocol_factory(options)
      protocol_class = super(
        options,
        Nginx::Builder::RailsHttp,
        Nginx::Builder::RailsHttps
      )

      # puts "Runner::Rails protocol_class: #{protocol_class}"
      # TODO: Each class has a subtly different group of lines here.
      # There's almost certainly a refactoring that would make this less
      # convoluted.
      domain_name = options.delete(:domain_name)
      user = options.delete(:user)
      certificate_domain = options.delete(:certificate_domain)
      accel_location = options.delete(:accel_location)
      # FIXME: This is the wrong way to do this.
      rails_env = options.delete(:rails_env) { "production" }
      domain = SharedInfrastructure::Domain.new(domain_name)
      protocol_class.new(user, certificate_domain, accel_location: accel_location, domain: domain, rails_env: rails_env)
    end
  end
end
