# frozen_string_literal: true

module Nginx
  ##
  # Server name and site location for a static site.
  # TODO: I don't like the way this gets twisted when subclassing.
  class Site < Server
    attr_reader :user

    def initialize(domain_name, user = "ubuntu")
      super domain_name
      @user = user
    end

    def to_s(level = 0)
      [
        super(level),
        Lines.new(
          "root #{Nginx.root_directory(domain_name)};",
          "index index.html index.htm;"
        ).format(level)
      ].join("\n\n")
    end
  end
end
