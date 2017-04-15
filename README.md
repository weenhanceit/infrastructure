# Infrastructure
Set up infrastructure for Weenhanceit projects.

## Architecture
One Amazon EC2 server with multiple static sites and/or Rails applications,
and one Amazon RDS instance.
Use Amazon CodeDeploy to deploy the application or static web site.

On the application server,
Nginx proxies the requests through to the appropriate Rails application,
or serves up the pages of the appropriate static web site.
There is an instance of Puma for each of the Rails applications.

## Prerequisites
This document assumes you've already set up an EC2 instance,
that CodeDeploy can deploy to the EC2 instance,
and that you've set up an RDS Postgres instance.

## Common First Steps
These steps are necessary whether you want to deploy
a static web site
or a Rails application.

1. Log in to the EC2 instance via SSH
```
    ssh -i ~/.ssh/weita.pem ubuntu@URL-of-ec2-instance
```
2. Get the set-up scripts:
```
    wget https://github.com/weenhanceit/infrastructure/archive/master.zip
```
3. Unzip it:
```
    unzip master.zip
```
4. `cd infrastructure-master/basic-app-server`

## One-Time Server Set-Up
This step is only necessary after you first set up the EC2 instance.
It installs additional software needed on the server.
```
./build.sh
```

## Creating a Static Web Site
This sets up an Nginx server block for a given domain name.
The root directory of the static web site files is `/var/www/*domain-name*/html`.
```
sudo ./create-server-block.sh *domain-name*
```
Now you can deploy the static web site. [TODO: How to deploy.]

## Creating a Rails Application
This sets up:

* An Nginx server block for a given domain name. The server block proxies via a domain socket to Puma
* A `systemd` service file that runs an instance of Puma
receiving requests on the same domain socket.

The root directory of the Rails application is `/var/www/*domain-name*/html`.
```
export SECRET_KEY_BASE=*secret-key-base*
export DATABASE_USERNAME=*database-username*
export DATABASE_PASSWORD=*database-password*
sudo ./create-rails-app.sh *domain-name*
export DATABASE=*database*
./create-db-user.sh
```
The last step above will ask you for the password for the `root` user in the Postgres database.

Now you can deploy the Rails app. [TODO: How to deploy.]

