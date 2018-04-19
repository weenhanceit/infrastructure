# frozen_string_literal: true

module Nginx
  class Accel
    def initialize(location_directory)
      @location_directory = location_directory.chomp("/").reverse.chomp("/").reverse
    end

    attr_reader :location_directory

    def alias_string(domain_name)
      File.join(Nginx.configuration.root_directory(domain_name), location_directory).to_s
    end

    def location
      "/#{location_directory}"
    end

    def proxy_set_header(domain_name)
      [
        "  proxy_set_header X-Sendfile-Type X-Accel-Redirect;",
        "  proxy_set_header X-Accel-Mapping #{alias_string(domain_name)}/=#{location}/;"
      ].join("\n")
    end
  end
end
