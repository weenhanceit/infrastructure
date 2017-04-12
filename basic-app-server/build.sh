#!/bin/bash
# Minimal We Enhance IT web server for static sites and Rails

sudo apt-get update -y -qq

sudo apt-get install -y -q linux-headers-$(uname -r) build-essential dkms
sudo apt-get install git
sudo apt-get install -y -q ruby ruby-dev

# Nokogiri build dependencies (from http://www.nokogiri.org/tutorials/installing_nokogiri.html#ubuntu___debian)
sudo apt-get install -y -q patch zlib1g-dev liblzma-dev

# Need this for at least one of our apps
sudo apt-get install -y -q pdftk

sudo apt-get install -y -q sqlite3 libsqlite3-dev

sudo apt-get -y -q install nginx

# For CodeDeploy in Canada
sudo apt-get install -y -q python-pip
wget https://aws-codedeploy-ca-central-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent start
# end CodeDeploy

sudo apt-get dist-upgrade -y -qq
sudo apt-get autoremove -y -qq
