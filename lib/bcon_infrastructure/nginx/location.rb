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

  class ReverseProxyLocation < Location
    def initialize(location, proxy_url)
      super location
      @proxy_url = proxy_url
    end

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
end
