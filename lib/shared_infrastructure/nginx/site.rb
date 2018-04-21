# frozen_string_literal: true

module Nginx
  ##
  # Server name and site location for a static site.
  # TODO: I don't like the way this gets twisted when subclassing.
  class Site < Server
    attr_reader :user

    def initialize(domain_name, user = "ubuntu", domain: nil)
      super domain_name, domain: domain
      @user = user
    end

    def root_directory
      # FIXME: Remove conditional when refactoring done
      domain ? domain.root_directory : Nginx.root_directory(domain_name)
    end

    def to_s(level = 0)
      [
        super(level),
        # FIXME: Remove conditional when refactoring done
        Lines.new(
          "root #{domain ? domain.root_directory : Nginx.root_directory(domain_name)};",
          "index index.html index.htm;"
        ).format(level)
      ].join("\n\n")
    end
  end
end
