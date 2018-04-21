# frozen_string_literal: true

module Nginx
  ##
  # The server_name line of a server block.
  class Server
    attr_reader :domain, :domain_name

    def initialize(domain_name, domain: nil)
      @domain_name = domain_name
      @domain = domain
    end

    def to_s(level = 0)
      # TODO: Remove the condition when done refactoring.
      if domain
        Lines.new("server_name #{domain.certbot_domain_names};").format(level)
      else
        Lines.new("server_name #{Nginx.certbot_domain_names(domain_name)};").format(level)
      end
    end
  end

  ##
  # Server name and site location for a static site.
  # TODO: I don't like the way this gets twisted when subclassing.
  class StaticServer < Server
    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "root #{domain ? domain.root_directory : root_directory};",
          "index index.html index.htm;"
        ).format(level)
      ].join("\n\n")
    end
  end

  class RailsServer < Server
    def root_directory
      File.join(Nginx.root_directory(domain_name), "public")
    end

    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "# http://stackoverflow.com/a/11313241/3109926 said the following",
          "# is what serves from public directly without hitting Puma",
          "root #{domain ? domain.root_directory : root_directory};",
          "try_files $uri/index.html $uri @#{domain ? domain.domain_name : domain_name};",
          "error_page 500 502 503 504 /500.html;",
          "client_max_body_size 4G;",
          "keepalive_timeout 10;"
        ).format(level)
      ].join("\n\n")
    end
  end
end
