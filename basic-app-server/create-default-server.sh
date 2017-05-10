#!/bin/bash

[[ -f /etc/nginx/sites-available/default ]] &&
  [[ ! -f /etc/nginx/sites-available/default.original ]] &&
  cp -a /etc/nginx/sites-available/default /etc/nginx/sites-available/default.original

cat >/etc/nginx/sites-available/default <<EOF
server {
  listen 80 default_server;
  # listen 443 default_server; Shouldn't redirect from HTTPS to HTTP
  listen [::]:80 default_server;
  # listen [::]:443 default_server;
  # Github Pages custom domains don't do HTTPS
  return 301 http://weenhanceit.com;
}
EOF
