#!/bin/bash
# Create a server block for nginx.
# Started from: https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts

usage() {
  echo usage: `basename $0` [-u user -hd] domain_name...
  cat <<EOF
  -d        Debug.
  -u  user  Make created files and directories owned by user.
  -h        This help.
EOF
}

while getopts dhu: x ; do
  case $x in
    d) debug=1;;
    u) user=$OPTARG;;
    h) usage; exit 0;;
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
for d in "$@"; do
  domain_names="${domain_names} $d www.$d"
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
puma_uri=unix:/tmp/$domain_name.sock

cat >$server_block_definition <<-EOF
upstream $domain_name {
    server $puma_uri;
    # server $puma_uri fail_timeout=0;
}

server {
  listen 80;
  listen [::]:80;
  server_name $domain_names;

  # http://stackoverflow.com/a/11313241/3109926 said the following
  # is what serves from public directly without hitting Puma
  root $root_directory/public;
  try_files \$uri/index.html \$uri @$domain_name;

  location @$domain_name {
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
