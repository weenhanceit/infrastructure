#!/bin/bash
# Create the systemd service file for a Puma instance (application)

if [ $# -lt 1 ]; then
  echo usage: $0 domain_name
  exit 1
fi

domain_name=$1
root_directory=/var/www/$domain_name/html

cat >/lib/systemd/system/$domain_name.service <<EOF
[Unit]
Description=Puma HTTP Server for $domain_name
After=network.target

# Uncomment for socket activation (see below)
# Requires=$domain_name.socket

[Service]
# Foreground process (do not use --daemon in ExecStart or config.rb)
Type=simple

User=nobody

# Specify the path to your puma application root
WorkingDirectory=$root_directory

# Helpful for debugging socket activation, etc.
# Environment=PUMA_DEBUG=1
# TODO: The following means we need to set up a Puma config file
# on the server in $root_directory/
Environment=RACK_ENV=production
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=This-is-not-a-secret
Environment=DATABASE_USERNAME=
Environment=DATABASE_PASSWORD=

# The command to start Puma
# Here we are using a binstub generated via:
# bundle binstubs puma --path ./sbin
# in the WorkingDirectory (replace <WD> below)
# You can alternatively use bundle exec --keep-file-descriptors puma
# NOTE: TLS would be handled by Nginx
# TODO: Check/fix this for sockets
ExecStart=/usr/local/bin/puma -b tcp://127.0.0.1:9292

# Alternatively with a config file (in WorkingDirectory) and
# comparable bind directives
# ExecStart=<WD>/sbin/puma -C config.rb

Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable $domain_name.socket
