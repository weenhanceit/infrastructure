class StaticHttpsBuilder < StaticHttpBuilder
  def build
    super
    `openssl dhparam #{@dhparam} -out #{@config.certificate_directory}/dhparam.pem`
  end

  def initialize(server_block_class, config, options)
    @dhparam = options[:dhparam] || 2048
    # puts "DHPARAM: #{@dhparam}"
    super server_block_class, config
  end
end
