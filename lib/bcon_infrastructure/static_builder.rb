require "optparse"

class StaticBuilder
  class << self
    def call(argv)
      puts argv
    end
  end

  def build
    File.open(server_block_location, "w") do |f|
      f << HttpServerBlock.new(@config).to_s
    end
  end

  def main(argv, config_class: Config)
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: [options]"
    end.parse!
    $stderr.puts "domain required" unless argv.size == 1
    @config = config_class.new(argv.first)
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
end
