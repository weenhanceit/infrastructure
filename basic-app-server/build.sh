#!/bin/bash
# Minimal We Enhance IT web server for static sites and Rails

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" |
  sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt-get update -y -qq

sudo apt-get install -y -q linux-headers-$(uname -r) build-essential dkms
sudo apt-get install git
sudo apt-get install -y -q ruby ruby-dev

# Nokogiri build dependencies (from http://www.nokogiri.org/tutorials/installing_nokogiri.html#ubuntu___debian)
sudo apt-get install -y -q patch zlib1g-dev liblzma-dev

# Need this for at least one of our apps
sudo apt-get install -y -q pdftk

sudo apt-get install -y -q postgresql-client libpq-dev
sudo apt-get install -y -q sqlite3 libsqlite3-dev
sudo apt-get install -y -q nodejs
sudo apt-get -y -q install nginx yarn

# Install Redis
# Adapted from: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-redis-on-ubuntu-16-04
# make test hangs on 4.0. Internet suggests: `taskset -c 1 make test`
# https://github.com/antirez/redis/issues/1417
# But above obviously doesn't work on single CPU Vagrant box.
# 3.2 passed test at least once.
# The version in the Ubuntu 16.04 repository is quite old (2.3)
# At the time of writing, the most recent version of 3 was 3.2,
# and 4.0 was already in use.
cd /tmp
sudo apt-get install -y -q tcl
curl -O http://download.redis.io/releases/redis-3.2.11.tar.gz
tar -xzvf redis-3.2.11.tar.gz
cd redis-3.2.11
# curl -O http://download.redis.io/redis-stable.tar.gz
# tar -xzvf redis-stable.tar.gz
# cd redis-stable
make
sudo make install
sudo adduser --system --group --no-create-home redis
sudo mkdir /var/lib/redis #/var/log/redis
sudo chown redis:redis /var/lib/redis #/var/log/redis
sudo chmod 770 /var/lib/redis #/var/log/redis
sudo sed -i.original \
  -e '/^supervised no/s/no/systemd/' \
  -e '/^dir/s;.*;dir /var/lib/redis;' \
  redis.conf
sudo cp redis.conf /etc
cat >redis.service <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo cp redis.service /etc/systemd/system/
echo This build does NOT start Redis.
echo To enable automatic start of Redis on system start, type:
echo sudo systemctl enable redis
cd ..
# Sendmail
sudo apt-get install -y -q sendmail

# For CodeDeploy in Canada
sudo apt-get install -y -q python-pip
wget https://aws-codedeploy-ca-central-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent start
# end CodeDeploy

# Set up for TLS (SSL) by installing certbot
# https://certbot.eff.org/#ubuntuxenial-nginx
# Uses Let's Encrypt certificates
# https://letsencrypt.org/
sudo add-apt-repository ppa:certbot/certbot -y
sudo apt-get update -y -qq
sudo apt-get install certbot -y -qq
# End set-up for TLS

sudo apt-get upgrade -y -qq
sudo apt-get dist-upgrade -y -qq
sudo apt-get autoremove -y -qq

sudo gem install rails -v 5.0.1 --no-document
