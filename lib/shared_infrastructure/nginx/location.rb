# frozen_string_literal: true

module Nginx
  class Location
    def initialize(location = "/")
      @location = location
    end

    def to_s(level = 0)
      Lines.new("location #{location} {",
        "  try_files $uri $uri/ =404;",
        "}").format(level)
    end

    private

    attr_reader :location
  end

  class AccelLocation < Location
    def initialize(domain_name, accel)
      super(location)
      @domain_name = domain_name
      @accel = accel
    end

    def to_s(level = 0)
      Lines.new("location #{accel.location} {",
        "  internal;",
        "  alias #{accel.alias_string(domain_name)};",
        "}").format(level)
    end

    attr_reader :accel, :domain_name
  end

  class AcmeLocation < Location
    def initialize(certificate_domain, location = "/.well-known")
      super(location)
      @certificate_domain = certificate_domain
    end

    def to_s(level = 0)
      Lines.new("location #{location} {",
        "  alias #{File.join(Nginx.root_directory(certificate_domain), ".well-known")};",
        "}").format(level)
    end

    attr_reader :certificate_domain, :location
  end

  class ActionCableLocation < Location
    def initialize(domain_name, location = "/cable")
      super(location)
      @domain_name = domain_name
    end

    def to_s(level = 0)
      Lines.new("location #{location} {",
        "  proxy_pass http://#{domain_name};",
        "  proxy_http_version 1.1;",
        "  proxy_set_header Upgrade $http_upgrade;",
        "  proxy_set_header Connection \"upgrade\";",
        "}").format(level)
    end

    private

    attr_reader :domain_name
  end

  class RailsLocation
    def initialize(domain_name)
      @domain_name = domain_name
    end

    def to_s(level = 0)
      Lines.new("location @#{domain_name} {",
        "  # A Rails app should force \"SSL\" so that it generates redirects to HTTPS,",
        "  # among other things.",
        "  # However, you want Nginx to handle the workload of TLS.",
        "  # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,",
        "  # but set the header to HTTPS",
        "  # Next two lines.",
        "  proxy_pass http://#{domain_name};",
        "  proxy_set_header X-Forwarded-Proto $scheme; # $scheme says http or https",
        "  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
        "  proxy_set_header Host $http_host;",
        "  proxy_redirect off;",
        "}").format(level)
    end

    private

    attr_reader :domain_name
  end

  class ReverseProxyLocation < Location
    def initialize(proxy_url, location = "/")
      super location
      @proxy_url = proxy_url
    end

    ##
    # Don't change any of the response headers
    # http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_redirect
    # The URI is added if none is specified in the proxy_url.
    def to_s(level = 0)
      Lines.new("location #{location} {",
        "  proxy_pass #{proxy_url};",
        "  proxy_set_header Host $http_host;",
        "  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
        "  proxy_set_header X-Forwarded-Proto $scheme;",
        "  proxy_set_header X-Real-IP $remote_addr;",
        "  proxy_redirect off;",
        "}").format(level)
    end

    private

    attr_reader :proxy_url
  end

  class RedirectLocation < Location
    def initialize
      super
      @location = nil
    end

    def to_s(level = 0)
      Lines.new("return 301 https://$server_name/$request_uri;").format(level)
    end
  end
end
