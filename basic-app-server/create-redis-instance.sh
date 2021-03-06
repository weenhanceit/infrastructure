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
redis=redis.$domain_name
redis_socket=$fake_root/tmp/$redis.sock
redis_dir=$fake_root/var/lib/$redis
redis_conf=$fake_root/etc/$redis.conf
user=${user:-nobody}
service_file=$fake_root/lib/systemd/system/$redis.service

if [[ $debug ]]; then
  echo Domain Name: $domain_name
  echo Redis: $redis
  echo Redis Socket: $redis_socket
  echo Redis Directory: $redis_dir
  echo Redis Configuration File: $redis_conf
  echo Service File: $service_file
  echo User: $user
fi

if [[ $debug || $fake_root ]]; then
  mkdir -p `dirname $redis_socket`
  mkdir -p `dirname $redis_conf`
  mkdir -p `dirname $service_file`
fi

sudo mkdir $redis_dir
sudo chown $user:$user $redis_dir
sudo chmod 770 $redis_dir

# Redis Config File
# The following edits should have been done by the basic install:
# -e '/^supervised no/s/no/systemd/' \
# And the following isn't needed to log to syslog
# -e "/^logfile/s;\"\";\"/var/log/redis/$redis.log\";" \
# TODO: Confirm that Redis is journalling changes so jobs are persistent.
# It looks like 16.04 had `/etc/redis.conf`, but 18.04 has `/etc/redis/redis.conf`
original_conf_file=/etc/redis/redis.conf
[ -f $original_conf_file ] || original_conf_file=/etc/redis.conf
sed \
  -e "/^dir/s;.*;dir $redis_dir;" \
  -e "/^port 6379/s//port 0/" \
  -e "/^# unixsocket /s;.*;unixsocket $redis_socket;" \
  -e "/^# unixsocketperm/s/^# //" \
  -e "/^logfile /s/redis-server.log/${redis}-server.log/" \
  $original_conf_file >$redis_conf

# find the Redis server and cli
redis_server=/usr/bin/redis-server
[ -f $redis_server ] || redis_server=/usr/local/bin/redis-server
redis_cli=/usr/bin/redis-cli
[ -f $redis_cli ] || redis_cli=/usr/local/bin/redis-cli

# Redis Service
# Assumes server build created redis user
cat >$service_file <<EOF
[Unit]
Description=Redis In-Memory Data Store for $domain_name
After=network.target

[Service]
User=redis
Group=redis

ExecStart=$redis_server $redis_conf
ExecStop=$redis_cli -s $redis_socket shutdown
Restart=always

[Install]
WantedBy=multi-user.target sidekiq.$domain_name.service $domain_name.service
EOF

# This works because you still have to start the service.
[[ $debug ]] || systemctl enable $redis.service
