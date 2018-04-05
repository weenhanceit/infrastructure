module Runner
  class Rails < Base
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
      user = options.delete(:user) || "ubuntu"
      certificate_domain = options.delete(:certificate_domain)
      protocol_class.new(domain_name, user, certificate_domain)
    end
  end
end
