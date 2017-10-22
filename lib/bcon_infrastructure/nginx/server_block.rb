##
# Write nginx configuration files.
module Nginx
  class ServerBlock
    include Files

    def initialize(server: nil, listen: nil, location: nil)
      @listen = listen
      @location = location
      @server = server
    end

    def save
      File.open(server_block_location(server.domain_name), "w") do |f|
        f << to_s
      end
      `ln -fs ../sites-available/#{server.domain_name} #{enabled_server_block_location(server.domain_name)}`
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

    private

    attr_reader :listen, :location, :server
  end
end
