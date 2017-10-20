# frozen_string_literal: true

require "optparse"

class StaticBuilder
  include BconInfrastructure::Files

  class << self
    def call(argv)
      puts argv
    end
  end

  def build
    @builder_class&.build
  end

  def main(config_class: Config)
    options = process_options

    # puts "OPTIONS: #{options.inspect}"
    # puts "ARGV: #{ARGV}"

    @config = config_class.new(ARGV.first, options_for_config(options))
    @builder_class = protocol_factory(options)
    self
  end

  def options_for_config(options)
    $stderr.puts "domain required" unless ARGV.size == 1
    options.select { |k, _v| k == :user }
  end

  def process_options
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: [options]"

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end

      opts.on("-p PROTOCOL",
        "--protocol PROTOCOL",
        "HTTP|HTTPS. Default: HTTPS if key files exist, else HTTP.") do |protocol|
        options[:protocol] = protocol
      end

      opts.on("-u USER",
        "--user USER",
        "User to be the owner of certain files. Default: ubuntu.") do |user|
        options[:user] = user
      end

      opts.on("--dhparam KEYSIZE",
        "KEYSIZE. Default: 2048 should be used. Option is for testing purposes.") do |dhparam|
        options[:dhparam] = dhparam
      end

      yield if block_given?
    end.parse!
    options
  end

  DELEGATE_TO_CONFIG = %i[
    certbot_domain_names
    certificate_directory
    domain_name
    domain_names
    fake_root
    root_directory
    server_block_location
    user
  ].freeze

  DELEGATE_TO_CONFIG.each do |method|
    define_method method do
      @config && @config.send(method)
    end
  end

  private

  def protocol_factory(options)
    klass = case options[:protocol]&.upcase
            when "HTTP"
              # puts "Branch A"
              StaticHttpBuilder.new(HttpServerBlock, @config)
            when "HTTPS"
              # puts "Branch B"
              StaticHttpsBuilder.new(HttpsServerBlock, @config, options)
            else
              if File.exist?(File.join(@config.certificate_directory, "privkey.pem")) &&
                 File.exist?(File.join(@config.certificate_directory, "fullchain.pem"))
                #  puts "Branch C"
                StaticHttpsBuilder.new(HttpsServerBlock, @config, options)
              else
                # puts "Branch D"
                # puts "privkey: #{File.exist?(File.join(@config.certificate_directory, "privkey.pem"))}"
                # puts "fullchain: #{File.exist?(File.join(@config.certificate_directory, "fullchain.pem"))}"
                # puts "privkey: #{File.join(@config.certificate_directory, "privkey.pem")}"
                # puts "fullchain: #{File.join(@config.certificate_directory, "fullchain.pem")}"
                StaticHttpBuilder.new(HttpServerBlock, @config)
              end
            end

    # puts "protocol_factory klass: #{klass}"
    klass
  end
end
