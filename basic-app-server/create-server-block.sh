#!/bin/bash
# Create a server block for nginx.
# Mostly from: https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts

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

if [[ $debug ]]; then
  echo Domain Names: $domain_names
  echo Root Directory: $root_directory
  echo Certificate Directory: $certificate_directory
  echo User: $user
fi

if [[ $debug || $fake_root ]]; then
  mkdir -p $certificate_directory
  mkdir -p `dirname $server_block_definition`
  mkdir -p $fake_root/etc/nginx/sites-enabled
fi

mkdir -p $root_directory
chown -R $user:www-data $root_directory

# cat >$root_directory/index.html <<-EOF
# <!doctype html>
# <head>
#   <title>Under Construction</title>
# </head>
# <body>
#   <h1>Under Construction</h1>
# </body>
# EOF

if [[ -z ${use_port+x} ]]; then
  if [[ ! -f $certificate_directory/privkey.pem ||
        ! -f $certificate_directory/fullchain.pem ]]; then
    use_port=80
  else
    use_port=443
  fi
fi

cat >$server_block_definition <<-EOF
server {
  server_name $domain_names;

  root $root_directory;
  index index.html index.htm;

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
  ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;
  ssl_certificate     /etc/letsencrypt/live/$domain_name/fullchain.pem;

  # Test the site using: https://www.ssllabs.com/ssltest/index.html
  # Optimize TLS, from: https://www.bjornjohansen.no/optimizing-https-nginx, steps 1-3
  ssl_session_cache shared:SSL:1m; # Enough for 4,000 sessions.
  ssl_session_timeout 180m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
  # Step 4
  ssl_dhparam /etc/letsencrypt/live/$domain_name/dhparam.pem;
  # Step 5
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /etc/letsencrypt/live/$domain_name/chain.pem;
  resolver 8.8.8.8 8.8.4.4;
  # Step 6 pin for a fortnight
  add_header Strict-Transport-Security "max-age=1209600" always;
  # Other steps TBD
EOF
else
  cat >>$server_block_definition <<-EOF
  listen 80;
  listen [::]:80;
EOF
fi

cat >>$server_block_definition <<-EOF

  location / {
    try_files \$uri \$uri/ =404;
  }
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

if [[ $use_port == 80 ]]; then
  cat <<EOF
You have to obtain a certificate and enable TLS for the site.
To do so, run the following command:

sudo certbot certonly --webroot -w $root_directory $certbot_domain_names

And test renewal with:

certbot renew --dry-run
EOF
fi
