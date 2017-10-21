# frozen_string_literal: true

class ReverseProxyBuilder < StaticBuilder
  def build
    @builder_class&.build
    @config.enable_site
  end

  def check_args
    $stderr.puts "domain and target url required" unless ARGV.size == 2
  end

  def options_for_config(options)
    super(options).merge(proxy_url: ARGV[1])
  end

  def process_options
    super do |opts|
      opts.on("-c DOMAIN",
        "--certificate-domain DOMAIN",
        "Use the certificate for DOMAIN.") do |certificate_domain|
        options[:certificate_domain] = certificate_domain
      end
    end
  end

  def protocol_factory(options)
    super(options,
      ReverseProxyHttpBuilder,
      ReverseProxyHttpServerBlock
    ) # , ReverseProxyHttpsServerBlock)
  end
end
