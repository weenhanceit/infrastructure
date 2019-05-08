# frozen_string_literal: true

require "optparse"

module Runner
  @debug = false
  class << self
    attr_accessor :debug
  end

  ##
  # Basic runner for nginx config file generation.
  class Base
    def main
      options = process_options

      puts "options: #{options.inspect}" if Runner.debug

      Nginx.prepare_fake_files(options[:domain_name], options[:certificate_domain]) if Nginx.root?

      @builder_class = protocol_factory(options)
      puts "builder_class: #{builder_class.inspect}" if Runner.debug
      builder_class
    end

    def options_for_config(options)
      options.select { |k, _v| k == :user }
    end

    def process_args(opts = nil)
      raise MissingArgument.new("domain required", opts) if ARGV.size == 0
      { domain_name: ARGV }
    end

    def process_options(http_builder_class = Nginx::Builder::SiteHttp,
      https_builder_class = Nginx::Builder::SiteHttps)
      options = {}
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: [options]"

        # FIXME: This is only applicable to Rails apps.
        opts.on("-a LOCATION",
          "--accel LOCATION",
          "Location below application root to serve when app responds with 'X-Accel'") do |accel_location|
          options[:accel_location] = accel_location
        end

        opts.on("-c DOMAIN",
          "--certificate-domain DOMAIN",
          "Use the certificate for DOMAIN.") do |certificate_domain|
          options[:certificate_domain] = certificate_domain
        end

        opts.on("-d", "--debug", "Print debugging information.") do
          options[:debug] = true
          Runner.debug = true
        end

        opts.on("-d RAILS_ENV", "--rails-env RAILS_ENV", "Build files for the specified RAILS_ENV") do |rails_env|
          options[:rails_env] = rails_env
        end

        opts.on("-P PROTOCOL",
          "--protocol PROTOCOL",
          "HTTP|HTTPS. Default: HTTPS if key files exist, else HTTP.") do |protocol|
          options[:protocol] = case protocol.upcase
                               when "HTTP"
                                 http_builder_class
                               when "HTTPS"
                                 https_builder_class
                               else
                                 opts.abort opts.help
                               end
        end

        opts.on("-r DIRECTORY",
          "--root DIRECTORY",
          "DIRECTORY. Set a root for files. This options is for debugging.") do |directory|
          Nginx.chroot(directory)
          SharedInfrastructure::Output.fake_root(directory)
        end

        opts.on("-u USER",
          "--user USER",
          "User to be the owner of certain files. Default: the current user.") do |user|
          options[:user] = user
        end

        opts.on("--dhparam KEYSIZE",
          "KEYSIZE. Default: 2048 should be used. This option is for testing.") do |keysize|
          Nginx.dhparam = keysize
        end

        options.merge! yield opts if block_given?
      end
      opts.parse!
      options.merge!(process_args(opts))
    end

    attr_reader :builder_class

    def protocol_factory(options,
      http_builder_class = Nginx::Builder::SiteHttp,
      https_builder_class = Nginx::Builder::SiteHttps)
      if options[:protocol]
        options[:protocol]
      else
        certificate_directory = Nginx.certificate_directory(
          options[:certificate_domain] || options[:domain_name].first # FIXME:
        )
        if File.exist?(File.join(certificate_directory, "privkey.pem")) &&
           File.exist?(File.join(certificate_directory, "fullchain.pem")) &&
           File.exist?(File.join(certificate_directory, "chain.pem")) &&
           File.exist?(File.join(certificate_directory, "cert.pem"))
          https_builder_class
        else
          http_builder_class
        end
      end
    end
  end

  class MissingArgument < RuntimeError
    def initialize(msg, opts)
      @opts = opts
      super msg
    end
    attr_reader :msg
    attr_reader :opts
  end
end
