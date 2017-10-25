class Test < MiniTest::Test
  # FIXME: This can go away, replaced by the next.
  EXPECTED_HTTPS_SERVER_BLOCK = %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam /etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    try_files $uri $uri/ =404;
  }
}
).freeze

  EXPECTED_STATIC_HTTPS_SERVER_BLOCK = %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam /etc/letsencrypt/live/example.com/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD

  location / {
    try_files $uri $uri/ =404;
  }
}
).freeze
#
# server {
#   server_name example.com www.example.com;
#   listen 80;
#   listen [::]:80;
#   return 301 https://$server_name/$request_uri;
# }

  EXPECTED_REVERSE_PROXY_HTTP_SERVER_BLOCK = %(server {
  server_name example.com www.example.com;

  listen 80;
  listen [::]:80;

  location / {
    proxy_pass http://search.example.com;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;
  }
}
).freeze

  EXPECTED_STATIC_HTTP_SERVER_BLOCK = %(server {
  server_name example.com www.example.com;

  root /var/www/example.com/html;
  index index.html index.htm;

  listen 80;
  listen [::]:80;

  location / {
    try_files $uri $uri/ =404;
  }
}
).freeze
  def expected_static_http_server_block
    %(server {
  server_name example.com www.example.com;

  root #{Nginx.root}/var/www/example.com/html;
  index index.html index.htm;

  listen 80;
  listen [::]:80;

  location / {
    try_files $uri $uri/ =404;
  }
}
).freeze
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

  root #{Nginx.root}/var/www/example.com/html;
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
).freeze
    end
  end

  def prepare_fake_files(domain_name)
    FileUtils.rm_rf Nginx.root, secure: true
    FileUtils.mkdir_p(File.dirname(Nginx.server_block_location(domain_name)))
    FileUtils.mkdir_p(File.dirname(Nginx.enabled_server_block_location(domain_name)))
  end
end