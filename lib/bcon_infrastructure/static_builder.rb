# frozen_string_literal: true

require "optparse"

class StaticBuilder
  class << self
    def call(argv)
      puts argv
    end
  end

  def build
    @builder_class&.build
  end

  def main(config_class: Config)
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: [options]"

      opts.on("-p PROTOCOL",
        "--protocol PROTOCOL",
        "HTTP|HTTPS. Default: HTTPS if key files exist, else HTTP.") do |protocol|
        options[:protocol] = protocol
      end

      opts.on("--dhparam KEYSIZE",
        "KEYSIZE. Default: 2048 should be used. Option is for testing purposes.") do |dhparam|
        options[:dhparam] = dhparam
      end
    end.parse!

    # puts "OPTIONS: #{options.inspect}"
    # puts "ARGV: #{ARGV}"

    $stderr.puts "domain required" unless ARGV.size == 1

    @config = config_class.new(ARGV.first)
    @builder_class = case protocol(options[:protocol])
                     when "HTTPS"
                       StaticHttpsBuilder.new(HttpsServerBlock, @config, options)
                     else
                       StaticHttpBuilder.new(HttpServerBlock, @config)
                     end
    self
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

  def protocol(protocol)
    return protocol.upcase unless protocol.nil?
    if File.exist?(File.join(@config.certificate_directory, "privkey.pem")) &&
       File.exist?(File.join(@config.certificate_directory, "fullchain.pem"))
      "HTTPS"
    else
      "HTTP"
    end
  end
end
