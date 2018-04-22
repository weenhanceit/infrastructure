# frozen_string_literal: true

module Nginx
  ##
  # Server name and site location for a static site.
  # TODO: I don't like the way this gets twisted when subclassing.
  class Site < Server
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
end
