# frozen_string_literal: true

module Nginx
  class Configuration
    def certificate_directory(domain_name)
      "#{root}/etc/letsencrypt/live/#{domain_name}"
    end

    def initialize(root = nil)
      @root = root
    end

    def root_directory(domain_name)
      "#{root}/var/www/#{domain_name}/html"
    end

    def server_block_location(domain_name)
      "#{root}/etc/nginx/sites-available/#{domain_name}"
    end

    def enabled_server_block_location(domain_name)
      "#{root}/etc/nginx/sites-enabled/#{domain_name}"
    end

    attr_accessor :root
  end

  class << self
    ##
    # Change root. If block is given, change the root only for the duration
    # of the block. If no block is given, is the same as configure.
    def chroot(root = nil)
      if block_given?
        save_root = configuration.root
        chroot(root)
        result = yield
        chroot(save_root)
        result
      else
        configuration.root = root
      end
    end

    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  %i[
    certificate_directory
    enabled_server_block_location
    root_directory
    server_block_location
  ].each do |method|
    define_method method do |domain_name|
      configuration.send(method, domain_name)
    end
  end
end
