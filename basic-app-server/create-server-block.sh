#!/bin/bash
# Create a server block for nginx.
# Mostly from: https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts

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

cat >$root_directory/index.html <<-EOF
<!doctype html>
<head>
  <title>Under Construction</title>
</head>
<body>
  <h1>Under Construction</h1>
</body>
EOF

server_block_definition=/etc/nginx/sites-available/$domain_name

cat >$server_block_definition <<-EOF
server {
  listen 80;
  listen [::]:80;

  root $root_directory;
  index index.html index.htm;

  server_name $domain_names;

  location / {
    try_files \$uri \$uri/ =404;
  }
}
EOF

ln -fs $server_block_definition /etc/nginx/sites-enabled/

cat <<EOF
You have to obtain a certificate and enable TLS for the site.
To do so, run the following command:

sudo certbot certonly --webroot -w $root_directory $certbot_domain_names

And test renewal with:

certbot renew --dry-run
EOF
