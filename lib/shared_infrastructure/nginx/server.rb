# frozen_string_literal: true

module Nginx
  ##
  # The server_name line of a server block.
  class Server
    def initialize(domain: nil)
      @domain = domain
    end

    attr_reader :domain

    def root_directory
      domain.site_root
    end

    def to_s(level = 0)
      Lines.new("server_name #{domain.certbot_domain_names};").format(level)
    end
  end

  class StaticServer < Server
    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "root #{root_directory};",
          "index index.html index.htm;"
        ).format(level)
      ].join("\n\n")
    end
  end

  class RailsServer < Server
    def root_directory
      File.join(domain.site_root, "public")
    end

    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "# http://stackoverflow.com/a/11313241/3109926 said the following",
          "# is what serves from public directly without hitting Puma",
          "root #{root_directory};",
          "try_files $uri/index.html $uri @#{domain.domain_name};",
          "error_page 500 502 503 504 /500.html;",
          "client_max_body_size 4G;",
          "keepalive_timeout 10;"
        ).format(level)
      ].join("\n\n")
    end
  end
end
