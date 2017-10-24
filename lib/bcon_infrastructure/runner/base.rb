##
# Basic runner for nginx config file generation.
class Base
  def check_args
    $stderr.puts "domain required" unless ARGV.size == 1
    true
  end

  def main(config_class: Config)
    options = process_options

    # puts "OPTIONS: #{options.inspect}"
    # puts "ARGV: #{ARGV}"
    check_args

    @config = config_class.new(ARGV.first, options_for_config(options))
    @builder_class = protocol_factory(options)
    self
  end

  def options_for_config(options)
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

      yield opts if block_given?
    end.parse!
    options
  end
end
