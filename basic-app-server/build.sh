#!/bin/bash
# Minimal We Enhance IT web server for static sites and Rails

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" |
  sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt-get update -y -qq

sudo apt-get install -y -q linux-headers-generic build-essential dkms
sudo apt-get install git
sudo apt-get install -y -q ruby ruby-dev

# Nokogiri build dependencies (from http://www.nokogiri.org/tutorials/installing_nokogiri.html#ubuntu___debian)
sudo apt-get install -y -q patch zlib1g-dev liblzma-dev

# Need this for at least one of our apps
sudo apt-get install -y -q pdftk

sudo apt-get install -y -q postgresql-client libpq-dev
sudo apt-get install -y -q nodejs nginx yarn

# Install Redis
sudo apt-get install -y -q redis redis-tools

sudo sed -i.original \
  -e '/^supervised no/s/no/systemd/' \
  -e '/^dir/s;.*;dir /var/lib/redis;' \
  /etc/redis/redis.conf

echo This build does NOT start Redis.
echo To enable automatic start of Redis on system start, type:
echo sudo systemctl enable redis

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

sudo gem install rails -v 5.2.2.1 --no-document
