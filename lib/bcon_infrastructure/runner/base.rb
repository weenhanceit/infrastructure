# frozen_string_literal: true

module Runner
  ##
  # Basic runner for nginx config file generation.
  class Base
    def main(config_class: Config)
      options = process_options
      options.merge!(process_args)

      puts "options: #{options.inspect}" if options[:debug]

      Nginx.prepare_fake_files(options[:domain_name]) if Nginx.root?

      @config = config_class.new(ARGV.first, options_for_config(options))
      @builder_class = protocol_factory(options)
      puts "builder_class: #{builder_class.inspect}" if options[:debug]
      builder_class
    end

    def options_for_config(options)
      options.select { |k, _v| k == :user }
    end

    def process_args
      $stderr.puts "domain required" unless ARGV.size == 1
      { domain_name: ARGV[0] }
    end

    def process_options(http_builder_class = Nginx::Builder::SiteHttp,
      https_builder_class = Nginx::Builder::SiteHttps)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: [options]"

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          exit
        end

        opts.on("-d", "--debug", "Print debugging information.") do
          options[:debug] = true
        end

        opts.on("-p PROTOCOL",
          "--protocol PROTOCOL",
          "HTTP|HTTPS. Default: HTTPS if key files exist, else HTTP.") do |protocol|
          options[:protocol] = case protocol
                               when "HTTP"
                                 http_builder_class
                               when "HTTPS"
                                 https_builder_class
                               else
                                 puts opts
                                 exit
                               end
        end

        opts.on("-r DIRECTORY",
          "--root DIRECTORY",
          "DIRECTORY. Set a root for files. This options is for debugging.") do |directory|
          Nginx.chroot(directory)
        end

        opts.on("-u USER",
          "--user USER",
          "User to be the owner of certain files. Default: ubuntu.") do |user|
          options[:user] = user
        end

        opts.on("--dhparam KEYSIZE",
          "KEYSIZE. Default: 2048 should be used. This option is for testing.") do |keysize|
          Nginx.dhparam = keysize
        end

        yield opts if block_given?
      end.parse!
      options
    end

    attr_reader :builder_class

    def protocol_factory(options,
      http_builder_class = Nginx::Builder::SiteHttp,
      https_builder_class = Nginx::Builder::SiteHttps)
      if options[:protocol]
        options[:protocol]
      else
        certificate_directory = Nginx.certificate_directory(options[:domain_name])
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
end
