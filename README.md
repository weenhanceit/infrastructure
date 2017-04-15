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
and you've set up an RDS Postgres instance.

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
```
./build.sh
```

## Creating a Static Web Site
```
./create-server-block.sh *domain-name*
```
Now you can deploy the static web site. [TODO: How to deploy.]

## Creating a Rails Application
```
export SECRET_KEY_BASE=*secret-key-base*
export DATABASE_USERNAME=*database-username*
export DATABASE_PASSWORD=*database-password*
./create-rails-app.sh *domain-name*
export DATABASE=*database*
./create-db-user.sh
```
The last step above will ask you for the password for the `root` user in the Postgres database.

Now you can deploy the Rails app. [TODO: How to deploy.]

