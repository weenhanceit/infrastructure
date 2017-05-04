#!/bin/bash

usage() {
  echo usage: `basename $0` [-u user -hd] domain_name...
  cat <<EOF
  -d            Debug.
  -h            This help.
  -p  [80|443]  Use HTTP or HTTPS (can't use both). Default based on presence of certificate files.
  -r directory  Install to fake root directory (for testing).
  -u  user      Make created files and directories owned by user.
EOF
}

while getopts dhp:r:u: x ; do
  case $x in
    d)  debug=1
        fake_root=${fake_root:-.};;
    h)  usage; exit 0;;
    p)  use_port=$OPTARG;;
    r)  fake_root=$OPTARG;;
    u)  user=$OPTARG;;
    \?) echo Invalid option: -$OPTARG
        usage
        exit 1;;
  esac
done
shift $((OPTIND-1))

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

domain_name=$1
domain_names=""
certbot_domain_names=""
for d in "$@"; do
  domain_names="${domain_names}$d www.$d "
  certbot_domain_names="${certbot_domain_names}-d $d -d www.$d "
done
root_directory=$fake_root/var/www/$domain_name/html
certificate_directory=$fake_root/etc/letsencrypt/live/$domain_name
user=${user:-ubuntu}

server_block_definition=$fake_root/etc/nginx/sites-available/$domain_name
service_file=$fake_root/lib/systemd/system/$domain_name.service

if [[ $debug ]]; then
  echo Domain Names: $domain_names
  echo Root Directory: $root_directory
  echo Certificate Directory: $certificate_directory
  echo User: $user
fi

if [[ $debug || $fake_root ]]; then
  mkdir -p $certificate_directory
  mkdir -p `dirname $server_block_definition`
  mkdir -p `dirname $service_file`
  mkdir -p $fake_root/etc/nginx/sites-enabled
fi

mkdir -p $root_directory
chown -R $user:www-data $root_directory

# Path to Puma SOCK file, as defined in the Puma config
# TODO: Check that the following is right
# puma_uri=127.0.0.1:9292
puma_uri=unix:///tmp/$domain_name.sock

# Nginx Server Block Definition

if [[ -z ${use_port+x} ]]; then
  if [[ ! -f $certificate_directory/privkey.pem ||
        ! -f $certificate_directory/fullchain.pem ]]; then
    use_port=80
  else
    use_port=443
  fi
fi

cat >$server_block_definition <<-EOF
upstream $domain_name {
  # server $puma_uri;
  server $puma_uri fail_timeout=0;
}

server {
  server_name $domain_names;

EOF

if [[ $use_port == 443 ]]; then
  if [[ ! -f $certificate_directory/dhparam.pem ]]; then
    openssl dhparam 2048 -out $certificate_directory/dhparam.pem
  fi

  cat >>$server_block_definition <<-EOF
  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # HTTP2 doesn't require encryption, but at last reading, no browsers support
  # HTTP2 without TLS, so only do http2 when we have TLS.
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  ssl_certificate_key $certificate_directory/privkey.pem;
  ssl_certificate     $certificate_directory/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam $certificate_directory/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate $certificate_directory/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Other steps TBD
EOF
else
  cat >>$server_block_definition <<-EOF
  listen 80;
  listen [::]:80;
EOF
fi

cat >>$server_block_definition <<-EOF

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root $root_directory/public;
  try_files \$uri/index.html \$uri @$domain_name;

  location @$domain_name {
    # A Rails app should force "SSL" so that it generates redirects to HTTPS,
    # among other things.
    # However, you want Nginx to handle the workload of TLS.
    # The trick to proxying to a Rails app, therefore, is to proxy pass to HTTP,
    # but set the header to HTTPS
    # Next two lines.
    proxy_pass http://$domain_name;
    proxy_set_header X-Forwarded-Proto \$scheme; # \$scheme says http or https
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_redirect off;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
EOF

if [[ $use_port == 443 ]]; then
  cat >>$server_block_definition <<-EOF

server {
  server_name $domain_names;
	listen 80;
	listen [::]:80;
	return 301 https://\$server_name/\$request_uri;
}
EOF
fi

ln -fs ../sites-available/$domain_name $fake_root/etc/nginx/sites-enabled/

# Puma Service

cat >$service_file <<EOF
[Unit]
Description=Puma HTTP Server for $domain_name
After=network.target

# Uncomment for socket activation (see below)
# Requires=$domain_name.socket

[Service]
# Foreground process (do not use --daemon in ExecStart or config.rb)
Type=simple

User=nobody
Group=www-data

# Specify the path to the Rails application root
WorkingDirectory=$root_directory

# Helpful for debugging socket activation, etc.
# Environment=PUMA_DEBUG=1
Environment=RACK_ENV=production
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=${SECRET_KEY_BASE:?"Please set SECRET_KEY_BASE=secret-key-base"}
Environment=DATABASE_USERNAME=${DATABASE_USERNAME:?"Please set DATABASE_USERNAME=username"}
Environment=DATABASE_PASSWORD=${DATABASE_PASSWORD:?"Please set DATABASE_PASSWORD=password"}

# The command to start Puma
# NOTE: TLS would be handled by Nginx
ExecStart=$root_directory/bin/puma -b $puma_uri \
  --redirect-stdout=$root_directory//log/puma-production.stdout.log \
  --redirect-stderr=$root_directory//log/puma-production.stderr.log
# ExecStart=/usr/local/bin/puma -b tcp://$puma_uri

Restart=always

[Install]
WantedBy=multi-user.target
EOF

chmod 600 $service_file

# # Puma Configuration File Setup
#
# puma_config_directory=$root_directory/config/puma
# puma_config_file=$puma_config_directory/production.rb
#
# mkdir -p $puma_config_directory
#
# cat >$puma_config_file <<EOF
# stdout_redirect "#{application_path}/log/puma-#{railsenv}.stdout.log",
#   "#{application_path}/log/puma-#{railsenv}.stderr.log",
#   true
# EOF
#
# chown $user:www-data $puma_config_file
# chmod 640 $puma_config_file

# This works because you still have to start the service.
[[ $debug ]] || systemctl enable $domain_name.service

if [[ $use_port == 80 ]]; then
  cat <<EOF
You have to obtain a certificate and enable TLS for the site.
To do so, reload the Nginx configuration:

sudo nginx -s reload

Then run the following command:

sudo certbot certonly --webroot -w $root_directory/public $certbot_domain_names

You can test renewal with:

sudo certbot renew --dry-run
EOF
fi
