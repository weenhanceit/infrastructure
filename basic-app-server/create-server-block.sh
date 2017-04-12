#!/bin/bash
# Create a server block for nginx.
# Mostly from: https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts

if [[ $# -lt 1 ]]; then
  echo usage: $0 domain_name
  exit 1
fi

domain_name=$1
root_directory=/var/www/$domain_name/html
user=ubuntu # TODO: Get the right user here

mkdir -p $root_directory

cat >$root_directory/index.html <<-EOF
<!doctype html>
<head>
  <title>Under Construction</title>
</head>
<body>
  <h1>Under Construction</h1>
</body>
EOF

chown -R $user:www-data $root_directory

server_block_definition=/etc/nginx/sites-available/$domain_name

cat >$server_block_definition <<-EOF
server {
    listen 80;
    listen [::]:80;

    root $root_directory;
    index index.html index.htm;

    server_name $domain_name www.$domain_name;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -fs $server_block_definition /etc/nginx/sites-enabled/
