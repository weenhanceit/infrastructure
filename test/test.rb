# frozen_string_literal: true

class Test < MiniTest::Test
  def key_file_list(domain_name)
    ["/tmp/builder_test/etc/letsencrypt/live/#{domain_name}/privkey.pem",
     "/tmp/builder_test/etc/letsencrypt/live/#{domain_name}/fullchain.pem",
     "/tmp/builder_test/etc/letsencrypt/live/#{domain_name}/chain.pem",
     "/tmp/builder_test/etc/letsencrypt/live/#{domain_name}/cert.pem"]
  end

  def expected_reverse_proxy_http_server_block
    %(server {
  server_name search.example.com www.search.example.com;

  listen 80;
  listen [::]:80;

  location /.well-known {
    alias #{Nginx.root}/var/www/example.com/html/.well-known;
  }

  location / {
    proxy_pass http://10.0.0.1;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;
  }
}
)
  end

  def expected_static_http_server_block
    %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  listen 80;
  listen [::]:80;

  location / {
    try_files $uri $uri/ =404;
  }
}
)
  end

  module TestHelpers
    def assert_directory(d)
      assert File.directory?(d), "#{d}: does not exist"
    end

    def assert_file(f)
      assert File.exist?(f), "#{f}: does not exist"
    end

    def assert_no_directory(d)
      assert !File.directory?(d), "#{d} should not exist"
    end

    def expected_https_server_block
      %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key #{Nginx.root}/etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     #{Nginx.root}/etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam #{Nginx.root}/etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate #{Nginx.root}/etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    try_files $uri $uri/ =404;
  }
}

server {
  server_name example.com www.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end

    def expected_https_server_block_certificate_domain
      %(server {
  server_name search.example.com www.search.example.com;

  root /var/www/search.example.com/html;
  index index.html index.htm;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key #{Nginx.root}/etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     #{Nginx.root}/etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam #{Nginx.root}/etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate #{Nginx.root}/etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    try_files $uri $uri/ =404;
  }
}

server {
  server_name search.example.com www.search.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end

    def expected_rails_http_x_accel_server_block
      %(upstream example.com {
  server unix:///tmp/example.com.sock fail_timeout=0;
}

server {
  server_name example.com www.example.com;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root /var/www/example.com/html/public;
  try_files $uri/index.html $uri @example.com;
  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;

  listen 80;
  listen [::]:80;

  proxy_set_header X-Sendfile-Type X-Accel-Redirect;
  proxy_set_header X-Accel-Mapping /var/www/example.com/releases/=/__x_accel/;

  location @example.com {
    # A Rails app should force "SSL" so that it generates redirects to HTTPS,
    # among other things.
    # However, you want Nginx to handle the workload of TLS.
    # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,
    # but set the header to HTTPS
    # Next two lines.
    proxy_pass http://example.com;
    proxy_set_header X-Forwarded-Proto $scheme; # $scheme says http or https
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  }

  location /__x_accel {
    internal;
    alias /var/www/example.com/releases;
  }

  location /cable {
    proxy_pass http://example.com;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
)
    end

    def expected_rails_http_server_block
      %(upstream example.com {
  server unix:///tmp/example.com.sock fail_timeout=0;
}

server {
  server_name example.com www.example.com;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root /var/www/example.com/html/public;
  try_files $uri/index.html $uri @example.com;
  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;

  listen 80;
  listen [::]:80;

  location @example.com {
    # A Rails app should force "SSL" so that it generates redirects to HTTPS,
    # among other things.
    # However, you want Nginx to handle the workload of TLS.
    # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,
    # but set the header to HTTPS
    # Next two lines.
    proxy_pass http://example.com;
    proxy_set_header X-Forwarded-Proto $scheme; # $scheme says http or https
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  }

  location /cable {
    proxy_pass http://example.com;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
)
    end

    def expected_rails_https_server_block
      %(upstream example.com {
  server unix:///tmp/example.com.sock fail_timeout=0;
}

server {
  server_name example.com www.example.com;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root /var/www/example.com/html/public;
  try_files $uri/index.html $uri @example.com;
  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key #{Nginx.root}/etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     #{Nginx.root}/etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam #{Nginx.root}/etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate #{Nginx.root}/etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location @example.com {
    # A Rails app should force "SSL" so that it generates redirects to HTTPS,
    # among other things.
    # However, you want Nginx to handle the workload of TLS.
    # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,
    # but set the header to HTTPS
    # Next two lines.
    proxy_pass http://example.com;
    proxy_set_header X-Forwarded-Proto $scheme; # $scheme says http or https
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  }

  location /cable {
    proxy_pass http://example.com;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}

server {
  server_name example.com www.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end

    def expected_rails_https_server_block_certificate_domain
      %(upstream search.example.com {
  server unix:///tmp/search.example.com.sock fail_timeout=0;
}

server {
  server_name search.example.com www.search.example.com;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root /var/www/search.example.com/html/public;
  try_files $uri/index.html $uri @search.example.com;
  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key #{Nginx.root}/etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     #{Nginx.root}/etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam #{Nginx.root}/etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate #{Nginx.root}/etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location @search.example.com {
    # A Rails app should force "SSL" so that it generates redirects to HTTPS,
    # among other things.
    # However, you want Nginx to handle the workload of TLS.
    # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,
    # but set the header to HTTPS
    # Next two lines.
    proxy_pass http://search.example.com;
    proxy_set_header X-Forwarded-Proto $scheme; # $scheme says http or https
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  }

  location /cable {
    proxy_pass http://search.example.com;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}

server {
  server_name search.example.com www.search.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end

    def expected_reverse_proxy_https_server_block
      %(server {
  server_name search.example.com www.search.example.com;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key #{Nginx.root}/etc/letsencrypt/live/search.example.com/privkey.pem;
  ssl_certificate     #{Nginx.root}/etc/letsencrypt/live/search.example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam #{Nginx.root}/etc/letsencrypt/live/search.example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate #{Nginx.root}/etc/letsencrypt/live/search.example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    proxy_pass http://10.0.0.1;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;
  }
}

server {
  server_name search.example.com www.search.example.com;

  listen 80;
  listen [::]:80;

  return 301 https://$server_name/$request_uri;
}
)
    end

    def fake_env
      ENV["SECRET_KEY_BASE"] = "my_SECRET_KEY_BASE"
      ENV["DATABASE_USERNAME"] = "my_DATABASE_USERNAME"
      ENV["DATABASE_PASSWORD"] = "my_DATABASE_PASSWORD"
      ENV["EMAIL_PASSWORD"] = "my_EMAIL_PASSWORD"
    end

    def expected_rails_logrotate_conf(rails_env = "production")
      <<~LOGROTATE
        compress

        /var/www/example.com/log/#{rails_env}.log {
          size 1M
          rotate 4
          copytruncate
          missingok
          notifempty
        }
      LOGROTATE
    end

    def expected_unit_file(rails_env = "production")
      <<~UNIT_FILE
        [Unit]
        Description=Puma HTTP Server for example.com
        After=network.target

        # Uncomment for socket activation (see below)
        # Requires=example.com.socket

        [Service]
        # Foreground process (do not use --daemon in ExecStart or config.rb)
        Type=simple

        User=nobody
        Group=www-data

        # Specify the path to the Rails application root
        WorkingDirectory=/tmp/builder_test/var/www/example.com/html

        # Helpful for debugging socket activation, etc.
        # Environment=PUMA_DEBUG=1
        Environment=RACK_ENV=#{rails_env}
        Environment=RAILS_ENV=#{rails_env}
        # FIXME: The following is the wrong place
        Environment=SECRET_KEY_BASE=my_SECRET_KEY_BASE
        Environment=DATABASE_USERNAME=my_DATABASE_USERNAME
        Environment=DATABASE_PASSWORD=my_DATABASE_PASSWORD
        Environment=EMAIL_PASSWORD=my_EMAIL_PASSWORD
        Environment=REDIS_URL=unix:///tmp/redis.example.com.sock

        # The command to start Puma
        # NOTE: TLS would be handled by Nginx
        ExecStart=/tmp/builder_test/var/www/example.com/html/bin/puma -b unix:///tmp/example.com.sock \
              --redirect-stdout=/tmp/builder_test/var/www/example.com/html/log/puma-#{rails_env}.stdout.log \
              --redirect-stderr=/tmp/builder_test/var/www/example.com/html/log/puma-#{rails_env}.stderr.log
        # ExecStart=/usr/local/bin/puma -b tcp://unix:///tmp/example.com.sock

        Restart=always

        [Install]
        WantedBy=multi-user.target
        UNIT_FILE
    end
  end
end
