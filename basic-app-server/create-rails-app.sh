#!/bin/bash

usage() {
  echo usage: `basename $0` [-u user -hd] domain_name...
  cat <<EOF
  -d            Debug.
  -h            This help.
  -p  [80|443]  Use HTTP or HTTPS (can't use both). Default based on presence of certificate files.
  -u  user      Make created files and directories owned by user.
EOF
}

while getopts dhp:u: x ; do
  case $x in
    d) debug=1;;
    h) usage; exit 0;;
    p) use_port=$OPTARG;;
    u) user=$OPTARG;;
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
root_directory=/var/www/$domain_name/html
user=${user:-ubuntu}

if [[ $debug ]]; then
  echo Domain Names: $domain_names
  echo Root Directory: $root_directory
  echo User: $user
  exit 0
fi

mkdir -p $root_directory
chown -R $user:www-data $root_directory

server_block_definition=/etc/nginx/sites-available/$domain_name

# Path to Puma SOCK file, as defined in the Puma config
# TODO: Check that the following is right
# puma_uri=127.0.0.1:9292
puma_uri=unix:///tmp/$domain_name.sock

# Nginx Server Block Definition

if [[ -z ${use_port+x} ]]; then
  if [[ ! -f /etc/letsencrypt/live/autism-funding.com/privkey.pem ||
        ! -f /etc/letsencrypt/live/autism-funding.com/fullchain.pem ]]; then
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
  cat >>$server_block_definition <<-EOF
  # TLS config from: http://nginx.org/en/docs/http/configuring_https_servers.html
  # Let's Encrypt file names and locations from: https://certbot.eff.org/docs/using.html#where-are-my-certificates
  listen 443 ssl;
  listen [::]:443 ssl;
  ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;
  ssl_certificate     /etc/letsencrypt/live/$domain_name/fullchain.pem;
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
    proxy_pass http://$domain_name;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_redirect off;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
EOF

# if [[ $use_port == 443 ]]; then
#   cat >>$server_block_definition <<-EOF
#
# server {
#   server_name $domain_names;
# 	listen 80;
# 	listen [::]:80;
# 	return 301 https://$server_name/$request_uri;
# }
# EOF
# fi

ln -fs $server_block_definition /etc/nginx/sites-enabled/

# Puma Service

service_file=/lib/systemd/system/$domain_name.service

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
systemctl enable $domain_name.service

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
