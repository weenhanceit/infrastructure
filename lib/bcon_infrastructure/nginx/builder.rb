# frozen_string_literal: true

module Nginx
  class Builder
    def initialize(domain_name, *server_blocks)
      @server_blocks = server_blocks
      @domain_name = domain_name
    end

    def save
      File.open(Nginx.server_block_location(domain_name), "w") do |f|
        f << to_s
      end
      `ln -fs ../sites-available/#{domain_name} #{Nginx.enabled_server_block_location(domain_name)}`
    end

    def to_s
      server_blocks.map(&:to_s).join("\n")
    end

    attr_reader :domain_name, :server_blocks
  end

  class SiteBuilder < Builder
    def initialize(domain_name, user, *server_blocks)
      super(domain_name, *server_blocks)
      @user = user
    end

    def save
      FileUtils.mkdir_p(Nginx.root_directory(domain_name))
      FileUtils.chown(user,
        "www-data",
        Nginx.root_directory(domain_name)) if Process.uid.zero?
      super
    end

    attr_reader :user
  end
end
