#!/bin/bash
# Create a server block for nginx.
# Started from: https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts

if [[ $# -lt 1 ]]; then
  echo usage: $0 domain_name [user]
  exit 1
fi

domain_name=$1
root_directory=/var/www/$domain_name/html
user=${2:-ubuntu}

mkdir -p $root_directory

# cat >$root_directory/index.html <<-EOF
# <!doctype html>
# <head>
#   <title>Under Construction</title>
# </head>
# <body>
#   <h1>Under Construction</h1>
# </body>
# EOF
#
chown -R $user:www-data $root_directory

server_block_definition=/etc/nginx/sites-available/$domain_name

# Path to Puma SOCK file, as defined in the Puma config
# TODO: Check that the following is right
puma_uri=127.0.0.1:9292
# puma_uri=unix:/tmp/$domain_name.sock

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
    # TODO: I'm confused about what to put for proxy_pass.
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
