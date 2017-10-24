# frozen_string_literal: true

module Nginx
  class Listen
    def initialize(port)
      @port = port
    end

    def to_s(level = 0)
      Lines.new("listen #{port};", "listen [::]:#{port};").format(level)
    end

    private

    attr_reader :port
  end

  class ListenHttp < Listen
    def initialize
      super 80
    end
  end

  class ListenHttps < Listen
    include Files

    def initialize(domain_name)
      @domain_name = domain_name
      super 443
    end

    def to_s(level = 0)
      Lines.new(
        "# TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html",
        "# HTTP2 doesn't require encryption, but at last reading, no browsers support",
        "# HTTP2 without TLS, so only do http2 when we have TLS.",
        "listen #{port} ssl http2;",
        "listen [::]:#{port} ssl http2;",
        "# Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates",
        "ssl_certificate_key #{certificate_directory(domain_name)}/privkey.pem;",
        "ssl_certificate     #{certificate_directory(domain_name)}/fullchain.pem;",
        "",
        "# Test the site using: https://www.ssllabs.com/ssltest/index.html",
        "# Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3",
        "ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.",
        "ssl_session_timeout 180m;",
        "ssl_protocols TLSv1 TLSv1.1 TLSv1.2;",
        "ssl_prefer_server_ciphers on;",
        "ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;",
        "# Step 4",
        "ssl_dhparam #{certificate_directory(domain_name)}/dhparam.pem;",
        "# Step 5",
        "ssl_stapling on;",
        "ssl_stapling_verify on;",
        "ssl_trusted_certificate #{certificate_directory(domain_name)}/chain.pem;",
        "resolver 8.8.8.8 8.8.4.4;",
        "# Step 6 pin for a fortnight",
        "add_header Strict-Transport-Security \"max-age=1209600\" always;",
        "# Other steps TBD"
      ).format(level)
    end

    private

    attr_reader :domain_name
  end
end
