#!/bin/bash

usage() {
  echo usage: `basename $0` [-u user -hd] domain_name...
  cat <<EOF
  -d            Debug.
  -h            This help.
  -r directory  Install to fake root directory (for testing).
  -u  user      Make created files and directories owned by user.
EOF
}

while getopts dhr:u: x ; do
  case $x in
    d)  debug=1
        fake_root=${fake_root:-.};;
    h)  usage; exit 0;;
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
sidekiq=sidekiq.$domain_name
redis=redis.$domain_name
root_directory=${fake_root:-/var/www/$domain_name/html}
user=${user:-ubuntu}
service_file=$fake_root/lib/systemd/system/$sidekiq.service

if [[ $debug ]]; then
  echo Domain Name: $domain_name
  echo Sidekiq: $sidekiq
  echo Redis: $redis
  echo Root Directory: $root_directory
  echo Service File: $service_file
  echo User: $user
fi

if [[ $debug || $fake_root ]]; then
  mkdir -p `dirname $service_file`
fi

# Sidekiq Service

cat >$service_file <<EOF
[Unit]
Description=Sidekiq instance for $domain_name
After=$redis.service

[Service]
# Foreground process (do not use --daemon in ExecStart or config.rb)
Type=simple

User=nobody
Group=www-data

# Specify the path to the Rails application root
WorkingDirectory=$root_directory

Environment=RACK_ENV=production
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=${SECRET_KEY_BASE:?"Please set SECRET_KEY_BASE=secret-key-base"}
Environment=DATABASE_USERNAME=${DATABASE_USERNAME:?"Please set DATABASE_USERNAME=username"}
Environment=DATABASE_PASSWORD=${DATABASE_PASSWORD:?"Please set DATABASE_PASSWORD=password"}
Environment=EMAIL_PASSWORD=${EMAIL_PASSWORD:?"Please set EMAIL_PASSWORD=password"}
Environment=REDIS_URL=/tmp/$redis.sock

# The command to start Sidekiq
ExecStart=/usr/local/bin/bundle exec sidekiq -e production
KillSignal=SIGTERM

Restart=always

SyslogIdentifier=$sidekiq

[Install]
WantedBy=multi-user.target
EOF

chmod 600 $service_file

# This works because you still have to start the service.
[[ $debug ]] || systemctl enable $sidekiq.service
