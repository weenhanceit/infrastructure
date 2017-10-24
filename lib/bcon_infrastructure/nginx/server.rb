# frozen_string_literal: true

module Nginx
  ##
  # The server_name line of a server block.
  class Server
    def initialize(domain_name)
      @domain_name = domain_name
    end

    def to_s(level = 0)
      Lines.new("server_name #{domain_name} www.#{domain_name};").format(level)
    end

    attr_reader :domain_name
  end

  ##
  # Server name and site location for a static site.
  # TODO: I don't like the way this gets twisted when subclassing.
  class StaticServer < Server
    include Files

    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "root #{root_directory(domain_name)};",
          "index index.html index.htm;"
        ).format(level)
      ].join("\n\n")
    end
  end
end
