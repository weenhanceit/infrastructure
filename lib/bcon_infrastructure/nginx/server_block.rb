##
# Write nginx configuration files.
module Nginx
  class ServerBlock
    def initialize(server: nil, listen: nil, location: nil)
      @listen = listen
      @location = location
      @server = server
    end

    def save
      # FIXME: Return error code or throw on problems.
      File.open(Nginx.server_block_location(server.domain_name), "w") do |f|
        f << to_s
      end
      `ln -fs ../sites-available/#{server.domain_name} #{Nginx.enabled_server_block_location(server.domain_name)}`
    end

    def to_s
      <<~SERVER_BLOCK
        server {
        #{[
          @server&.to_s(1),
          @listen&.to_s(1),
          @location&.to_s(1)
        ].compact.join("\n\n")}
        }
      SERVER_BLOCK
    end

    private

    attr_reader :listen, :location, :server
  end

  class StaticServerBlock < ServerBlock
    def save
      # FIXME: Return error code or throw on problems.
      FileUtils.mkdir_p(Nginx.root_directory(server.domain_name))
      FileUtils.chown(server.user,
        "www-data",
        Nginx.root_directory(server.domain_name)) if Process.uid.zero?
      super
    end
  end
end
