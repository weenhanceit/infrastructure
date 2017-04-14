#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo usage: $0 domain_name [user]
  exit 1
fi

domain_name=$1
root_directory=/var/www/$domain_name/html
user=${2:-ubuntu}

mkdir -p $root_directory
chown -R $user:www-data $root_directory

server_block_definition=/etc/nginx/sites-available/$domain_name

# Path to Puma SOCK file, as defined in the Puma config
# TODO: Check that the following is right
puma_uri=127.0.0.1:9292
# puma_uri=unix:/tmp/$domain_name.sock

# Server Block Definition

cat >$server_block_definition <<-EOF
upstream app {
    server $puma_uri;
    # server $puma_uri fail_timeout=0;
}

server {
  listen 80;
  listen [::]:80;
  server_name $domain_name www.$domain_name;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root $root_directory/public;
  try_files \$uri/index.html \$uri @app;

  location @app {
    proxy_pass http://app;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_redirect off;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
EOF

ln -fs $server_block_definition /etc/nginx/sites-enabled/

# Puma Service

cat >/lib/systemd/system/$domain_name.service <<EOF
[Unit]
Description=Puma HTTP Server for $domain_name
After=network.target

# Uncomment for socket activation (see below)
# Requires=$domain_name.socket

[Service]
# Foreground process (do not use --daemon in ExecStart or config.rb)
Type=simple

User=nobody

# Specify the path to your puma application root
WorkingDirectory=$root_directory

# Helpful for debugging socket activation, etc.
# Environment=PUMA_DEBUG=1
# TODO: The following means we need to set up a Puma config file
# on the server in $root_directory/
Environment=RACK_ENV=production
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=${SECRET_KEY_BASE:?"Plese set SECRET_KEY_BASE=secret-key-base"}
Environment=DATABASE_USERNAME=${DATABASE_USERNAME:?"Plese set DATABASE_USERNAME=secret-key-base"}
Environment=DATABASE_PASSWORD=${DATABASE_PASSWORD:?"Plese set DATABASE_PASSWORD=secret-key-base"}

# The command to start Puma
# NOTE: TLS would be handled by Nginx
# TODO: Check/fix this for sockets
ExecStart=/usr/local/bin/puma -b tcp://$puma_uri

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# This works because you still have to start the service,
# but if someone reboots the server before the app is deployed, you'll get
# failures from systemd.
systemctl enable $domain_name.socket
