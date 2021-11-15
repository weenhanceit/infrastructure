# frozen_string_literal: true

##
# Write nginx configuration files.
module Nginx
  class ServerBlock
    def initialize(upstream: nil, server: nil, listen: nil, location: nil, accel_location: nil, domain: nil)
      @accel_location = accel_location
      @domain = domain
      @listen = listen
      @location = Array(location)
      @server = server
      @upstream = upstream
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
          @accel_location&.proxy_set_header(server.domain.domain_name),
          @location&.map { |l| l.to_s(1) }
        ].compact.join("\n\n")}
        }
      SERVER_BLOCK
    end

    def upstream_string
      upstream&.to_s
    end

    attr_reader :accel_location, :domain, :listen, :location, :server, :upstream
  end

  class TlsRedirectServerBlock < ServerBlock
    def initialize(*domain_names)
      super(
        server: Server.new(domain: SharedInfrastructure::Domain.new(*domain_names)),
        listen: ListenHttp.new,
        location: RedirectLocation.new
      )
    end
  end
end
