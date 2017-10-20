# frozen_string_literal: true

class ReverseProxyBuilder < StaticBuilder
  def parse_options
    super do
      opts.on("-c DOMAIN",
        "--certificate-domain DOMAIN",
        "Use the certificate for DOMAIN.") do |certificate_domain|
        options[:certificate_domain] = certificate_domain
      end
    end
  end

  def options_for_config(options)
    $stderr.puts "domain and target url required" unless ARGV.size == 2
    super(options).merge(proxy_url: ARGV.second)
  end
end
