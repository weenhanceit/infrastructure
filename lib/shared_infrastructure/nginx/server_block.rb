# frozen_string_literal: true

##
# Write nginx configuration files.
module Nginx
  class ServerBlock
    def initialize(upstream: nil, server: nil, listen: nil, location: nil)
      @listen = listen
      @location = Array(location)
      @server = server
      @upstream = upstream
    end

    def save
      File.open(Nginx.server_block_location(server.domain_name), "w") do |f|
        f << to_s
      end
      `ln -fs ../sites-available/#{server.domain_name} #{Nginx.enabled_server_block_location(server.domain_name)}`
    end

    def to_s
      [
        upstream_string,
        server_block_string
      ].compact.join("\n\n")
    end

    private

    def server_block_string
      <<~SERVER_BLOCK
        server {
        #{[
          @server&.to_s(1),
          @listen&.to_s(1),
          @location&.map { |l| l.to_s(1) }
        ].compact.join("\n\n")}
        }
SERVER_BLOCK
    end

    def upstream_string
      upstream&.to_s
    end

    attr_reader :listen, :location, :server, :upstream
  end

  class SiteServerBlock < ServerBlock
    def make_root_directory(root_directory)
      FileUtils.mkdir_p(server.root_directory)
      if Process.uid.zero?
        FileUtils.chown(server.user,
          "www-data",
          server.root_directory)
      end
    end

    def save
      make_root_directory(root_directory)
      super
    end
  end

  class RailsServerBlock < SiteServerBlock
    def root_directory
      File.join(server.root_directory, "/public")
    end
  end

  class StaticServerBlock < SiteServerBlock
  end

  class TlsRedirectServerBlock < ServerBlock
    def initialize(domain_name)
      super(
        server: Server.new(domain_name),
        listen: ListenHttp.new,
        location: RedirectLocation.new
      )
    end
  end
end
