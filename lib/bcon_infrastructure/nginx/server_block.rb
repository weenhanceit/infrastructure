##
# Write nginx configuration files.
module Nginx
  class ServerBlock
    def initialize(server: nil, listen: nil, location: nil)
      @server = server
      @listen = listen
      @location = location
    end

    def to_s
      <<~SERVER_BLOCK
        server {
        #{[
          @server.to_s(1),
          @listen.to_s(1),
          @location.to_s(1)
        ].compact.join("\n\n")}
        }
      SERVER_BLOCK
    end
  end
end
