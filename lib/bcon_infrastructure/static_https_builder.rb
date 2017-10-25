class StaticHttpsBuilder < StaticHttpBuilder
  def add_force_tls
    File.open(@config.server_block_location, "a") do |f|
      f << %(
server {
  server_name #{@config.domain_names};

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end
  end

  def build
    super
    add_force_tls
    @config.make_certificate_directory
    `openssl dhparam #{@dhparam} -out #{@config.certificate_directory}/dhparam.pem`
  end

  def initialize(server_block_class, config, options = {})
    @dhparam = options[:dhparam] || 2048
    # puts "DHPARAM: #{@dhparam}"
    super server_block_class, config
  end
end
