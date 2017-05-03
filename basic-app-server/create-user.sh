#!/bin/bash

usage() {
  echo usage: `basename $0` [-hd] username keyfile remotelogin
  cat <<EOF
  -d  Debug.
  -h  This help.
  -k  keyfile to log into remote system as existing user
  -p  port
EOF
}

while getopts dhk:p: x ; do
  case $x in
    d)  debug=1
        FAKE_ROOT=.;;
    h)  usage; exit 0;;
    k)  keyfile=$OPTARG
        keyfile_arg="-i $keyfile"
        ssh_command="${ssh_command:-ssh} $keyfile_arg"
        ;;
    p)  port=$OPTARG
        port_arg="-p $port"
        ssh_command="${ssh_command:-ssh} $port_arg"
        ;;
    \?) echo Invalid option: -$OPTARG
        usage
        exit 1;;
  esac
done
shift $((OPTIND-1))

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

# Here we have to manually copy the key to the EC2 instance and then
# add it to the end of the new user's ~/.ssh/authorized_keys
# The variable expansion expands to nothing if there is no ssh_command.
rsync ${ssh_command:+-e "$ssh_command"} $2 $3:

$ssh_command $3 <<EOF
sudo adduser --disabled-password --gecos ,,,, $1

if [[ ! -d /home/$1/.ssh ]]; then
  sudo mkdir -p /home/$1/.ssh
  sudo chmod 700 /home/$1/.ssh
  sudo chown $1:$1 /home/$1/.ssh
fi
if [[ ! -f /home/$1/.ssh/authorized_keys ]]; then
  sudo touch /home/$1/.ssh/authorized_keys
  sudo chmod 600 /home/$1/.ssh/authorized_keys
  sudo chown $1:$1 /home/$1/.ssh/authorized_keys
fi
sudo bash -c "cat `basename $2` >> /home/$1/.ssh/authorized_keys"
sudo rm `basename $2`

sudo bash -c "echo '$1 ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/$1"
if sudo visudo -q -c -f /etc/sudoers.d/$1; then
  sudo chmod 440 /etc/sudoers.d/$1
else
  echo /etc/sudoers.d/$1: Invalid syntax. Permissions not changed.
fi
EOF
