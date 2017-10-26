# frozen_string_literal: true

require "fileutils"

module Nginx
  class Configuration
    def certbot_domain_names(domain_name)
      "#{domain_name} www.#{domain_name}"
    end

    def certificate_directory(domain_name)
      "#{root}/etc/letsencrypt/live/#{domain_name}"
    end

    def initialize(root = nil)
      @dhparam = 2048
      @root = root
    end

    def root?
      !(root.nil? || root.empty?)
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

    attr_accessor :dhparam, :root
  end

  class << self
    ##
    # Change root. If block is given, change the root only for the duration
    # of the block. If no block is given, is the same as configure.
    def chroot(root = nil)
      if block_given?
        begin
          save_root = configuration.root
          chroot(root)
          result = yield
        ensure
          chroot(save_root)
          result
        end
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

    def dhparam
      configuration.dhparam
    end

    def dhparam=(key_length)
      configuration.dhparam = key_length
    end

    def prepare_fake_files(domain_name)
      ::FileUtils.mkdir_p(File.dirname(server_block_location(domain_name)))
      ::FileUtils.mkdir_p(File.dirname(enabled_server_block_location(domain_name)))
      ::FileUtils.mkdir_p(certificate_directory(domain_name))
    end

    def root
      configuration.root
    end

    def root?
      configuration.root?
    end

    %i[
      certbot_domain_names
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
end
