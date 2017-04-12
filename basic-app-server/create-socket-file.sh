#!/bin/bash
# Create the systemd socket file for a Puma instance (application)
# From: https://github.com/puma/puma/blob/master/docs/systemd.md#socket-activation

if [[ $# -lt 1 ]]; then
  echo usage: $0 domain_name
  exit 1
fi

domain_name=$1

cat >/lib/systemd/system/$domain_name.socket <<-EOF
  [Unit]
  Description=Puma HTTP Server Accept Sockets

  # TODO: Check that the following is right
  [Socket]
  # These two would be for http/https
  ListenStream=0.0.0.0:9292
  ListenStream=0.0.0.0:9293

  # AF_UNIX domain socket
  # SocketUser, SocketGroup, etc. may be needed for Unix domain sockets
  # SocketGroup=www-data
  # SocketMode=0777
  # ListenStream=/tmp/$domain_name.sock

  # Socket options matching Puma defaults
  NoDelay=true
  ReusePort=true
  Backlog=1024

  [Install]
  WantedBy=sockets.target
EOF

systemctl enable $domain_name.socket
