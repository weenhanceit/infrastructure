# frozen_string_literal: true

# Matt's post was very helpful: https://mattbrictson.com/accelerated-rails-downloads

module Nginx
  class Accel
    def initialize(location_directory, domain: nil)
      @domain = domain
      @location_directory = location_directory.chomp("/").reverse.chomp("/").reverse
    end

    attr_reader :domain, :location_directory

    def alias_string
      File.join(domain.root, location_directory).to_s
    end

    def location
      "/__x_accel"
    end

    def proxy_set_header(_domain_name)
      [
        "  proxy_set_header X-Sendfile-Type X-Accel-Redirect;",
        "  proxy_set_header X-Accel-Mapping #{alias_string}/=#{location}/;"
      ].join("\n")
    end
  end
end
