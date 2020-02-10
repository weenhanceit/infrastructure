# Infrastructure

Set up infrastructure for Weenhanceit projects. It covers one-time tasks that need to be done after bringing up a stock Ubuntu 18.04 server, and tasks that need to be done for each domain name/web site that you want to deploy to the server.

This document does not cover:

- How to create an AWS server (or any other kind of server)
- How to set up a DNS entry to point at the server. In order for users to access a web site that is set up according to this documentation, you need to have a DNS somewhere that associations the domain name with the IP address of the server.

## Architecture

One server with multiple static sites and/or Rails applications,
and one database instance on another server.

On the application server,
Nginx proxies the requests through to the appropriate Rails application,
or serves up the pages of the appropriate static web site.
There is an instance of Puma for each of the Rails applications.

Each Rails application has its database configuration
to talk to a database on the database server.

For applications that need Redis,
we run a separate Redis instance for each application.
The Redis instance listens on a domain socket
at `/tmp/redis.domain_name`.

## Prerequisites

This document assumes you've already set up an Ubuntu 18.04 server,
and a Postgres instance.

## Common First Steps

These steps are necessary whether you want to deploy
a static web site
or a Rails application.

1. Log in to the server via SSH (`<original key file>` is from AWS or other provider)

```bash
    ssh -i ~/.ssh/<original key file> ubuntu@<URL-of-server>
```

2. Get the set-up scripts:

```bash
    wget https://github.com/weenhanceit/infrastructure/archive/master.zip
```

3. Unzip it:

```bash
    unzip master.zip
```

## One-Time Server Set-Up

This step is only necessary after you first set up the server.
It installs additional software needed on the server.

```bash
infrastructure-master/basic-app-server/build.sh
```

Also install the gem:

```bash
sudo gem install shared-infrastructure --no-document
```

### Creating Users

Here's how to create named users with sudo privileges on the server.
These instructions work if your desktop is running Ubuntu.

1. Create a key pair on your local workstation if you don't already have one. Accept the defaults,
and don't enter a pass phrase:

```bash
    mkdir ~/.ssh
    chmod 700 ~/.ssh  
    ssh-keygen -t rsa
```

  This leaves a key pair in `~/.ssh/id_rsa` (the private key)
  and `~/.ssh/id_rsa.pub` (the public key).

2. Log into the new (remote) server:

```bash
    ssh -i ~/.ssh/<original key file> ubuntu@<URL-of-server>
```

3. Create the new user. You have to enter a password here. You will need the password when executing `sudo`, but it won't be used for logging in:

```bash
    sudo adduser --gecos "" <new-user-name>
    sudo adduser <new-user-name> sudo
```

4. On the local workstation again, upload your public key to allow login to the remote server without a password:

```bash
    ssh-copy-id <new-user-name>@<URL-of-server>
```

5. Test that the login works without a password:

```bash
    ssh <new-user-name>@<URL-of-server>
```

6. If login is working without a password, go back to the remote server, and disallow logins with password,
and clean out the history so as not to possibly leak any information about users:

```bash
    sudo passwd -l <new-user-name>
    history -c && history -w
```

## Creating a Static Web Site

This sets up an Nginx server block for a given domain name.
In all the examples that follow,
replace `domain-name` with your domain name.

```bash
sudo create-server-block -u <deploy-run-user-name> <domain-name>
```

The root directory of the static web site files is `/var/www/<domain-name>/html`.

Now you can deploy the static web site. [TODO: How to deploy.]

Once deployed, remember to reload the Nginx configuration:

```bash
sudo nginx -s reload
```

## Creating a Rails Application

This sets up:

* An Nginx server block for a given domain name. The server block proxies via a domain socket to Puma
* A `systemd` service file that runs an instance of Puma
receiving requests on the same domain socket.

### Rails Environment Variables

Earlier versions of this gem initialized some environment variables in the `systemd` unit file. We no longer do so, because it's incompatible with the Rails 5.2 way of handling secrets, which is now our standard way of handling secrets.

### Create the Rails Application

Creating the Rails application includes:

- Running a program to set up:
  - Nginx configuration files to forward requests to your domain, to the Rails application
  - `systemd` files to start the Rails application automatically when the server starts
- Creating a user in the database for the application

If the application does *not* use `send_file` to ask Nginx to send private files:

```bash
sudo create-rails-app -u <deploy-run-user-name> <domain-name>
```

If the application uses uses `send_file` to ask Nginx to send private files, add the `-a` flag:

```bash
sudo create-rails-app -u <deploy-run-user-name> -a <location> <domain-name>
```

Where `location` is the name of the directory under `Rails.root` where the private files are found (typically `/private`).

If you forget to use the `-a` or `-u` flags,
you can safely re-run this script later with the flag.

The above will tell you how to get a certificate for the site,
but you can't do that yet.
You need to deploy the application the first time,
so the directories get created.

Finally, set up the database. The following is what you need for an AWS RDS database:

```bash
psql -h <DB host name> -U <master user> -d postgres
create role <user name for application>
  with createdb
  login password '<password for application user>';
grant rds_superuser to <user name for application>;
\q
psql -h <DB host name> -U <user name for application> -d postgres
<enter password for application user>
create database <database for application>;
\q
```

The last step above will ask you for the password for the `root` user in the Postgres database.

The root directory of the Rails application is `/var/www/<domain-name>/html`.

Now you can deploy the Rails app.
Note that before you deploy,
you have to do `bundle binstubs puma`
in your Rails app, and then commit the `bin` directory to Github (or another accessible repository).

Assuming the Rails application has been prepared for deploy via Capistrano, try to deploy it now:

```bash
cap production deploy
```

The first deploy will fail, since neither the credentials nor the database exist.
After the first deploy has failed, copy the `master.key` file to the appropriate place on the server.
Go to the root directory of the Rails application on your workstation and type:

```bash
rsync config/master.key <URL-of-server>:/var/www/<domain-name>/shared/config
```

Then, log in to the application server as the deploy/run user and do:

```bash
cd /var/www/<domain name>/html/
rails db:setup
```

Once deployed, remember to reload the Nginx configuration:

```bash
sudo nginx -s reload
```

The deployment script should start the Puma service.
Check Puma's status with:

```bash
sudo systemctl status <domain-name>
```

If it's not running, try to restart it with:

```bash
sudo systemctl restart <domain-name>
```

If Puma isn't running, `/var/log/syslog` is a good place to look for hints as to what's wrong.
Note that `systemd` tries several times to start the application, so you will likely see the same set of messages repeated near the end of `/var/log/syslog`.

### Set Up Redis for a Rails Application

The [One Time Server Setup](one-time-server-setup) installs Redis
with a basic configuration
useful for simple Redis testing.
For production applications
on a shared host
further build and configuration are required.

Our approach is to use at least one Redis instance per application.
This allows us to configure each Redis application,
and reduces the impact of a possible compromise of a Redis instance.

To create an instance of Redis for a Rails application at a given domain-name,
type:

```bash
sudo ./create-redis-instance.sh <domain-name>
```

This creates the configuration file
and necessary directories
to run an instance of Redis for the application.
A `systemd` unit file is created,
so you can start the instance of Redis using:

```bash
sudo systemctl start redis.<domain-name>
```

and stop the instance of Redis using:

```bash
sudo systemctl stop redis.<domain-name>
```

You can see the status of the instance of Redis using:

```
sudo systemctl status redis.<domain-name>
```
The Redis log messages are written to `/var/log/syslog`.

The create script sets up the Redis instance to automatically start
when the server starts,
but it doesn't start the instance when it's first created.
Remember to start the instance with:
```
sudo systemctl start redis.<domain-name>
```

### Set Up the Rails Application for Sidekiq

The Sidekiq configuration in the Rails application
must be set correctly to work with the our standard production infrastructure.
`config/sidekiq.yml` must contain at least this:

```YAML
:queues:
  - default
  - mailers
```

`config/initializers/sidekiq.rb` must contain at least this:

```Ruby
url = case Rails.env
when "production"
  ENV[REDIS_URL]
else
  "localhost:6379"
end

end
Sidekiq.configure_server do |config|
  config.redis = { url: url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: url }
end
```

### Set Up Sidekiq for a Rails Application

To set up Sidekiq for a Rails application,
first [Set Up Redis for a Rails Application](set-up-redis-for-a-rails-application)
Then,
[create a Rails application](creating-a-rails-application).

and install the Rails application and make sure it's running.
Since Sidekiq in many ways is running the Rails application
in another instance,
make sure the Rails application runs
before trying to debug Sidekiq problems.

To create an instance of Sidekiq for a Rails application at a given domain-name,
[set up the environment variables for the Rails application](setting-the-rails-environment-variables),
if they're not already set.

Then, type:

```bash
sudo -E ./create-sidekiq-instance.sh <domain-name>
```

(Don't forget the `-E` to `sudo`.
It causes the environment variables to be passed to the script.)
This creates the configuration file
and necessary directories
to run an instance of Sidekiq for the application.
A `systemd` unit file is created,
so you can start the instance of Sidekiq using:

```bash
sudo systemctl start sidekiq.<domain-name>
```

and stop the instance of Sidekiq using:

```bash
sudo systemctl stop sidekiq.<domain-name>
```

You can see the status of the instance of Sidekiq using:

```bash
sudo systemctl status sidekiq.<domain-name>
```

The Sidekiq log messages are written to `/var/log/syslog`.

The create script sets up the Sidekiq instance to automatically start
when the server starts,
but it doesn't start the instance when it's first created.
Remember to start the instance with:

```bash
sudo systemctl start sidekiq.<domain-name>
```

## TLS (formerly SSL)

All Internet traffic should be encrypted,
if you want to be a good Internet citizen.
We get certificates from [Let's Encrypt](https://letsencrypt.org),
using the [EFF's Certbot](https://certbot.eff.org).
You should read the documentation for both of those
before you run the scripts to create HTTPS sites.

Certbot needs a running web server,
and these scripts require that the web server be responding to port 80.
So you have to do the above installation steps
to create the site for HTTP
before proceeding with the rest of this section,
which configures the site for HTTPS.

For Rails apps,
run this command and answer its questions to obtain and install certificates:

```bash
sudo certbot certonly --webroot -w /var/www/<domain-name>/html/public -d <domain-name> [-d <domain-name>]...
```

For static sites,
run this command and answer its questions to obtain and install certificates:

```bash
sudo certbot certonly --webroot -w /var/www/<domain-name>/html -d <domain-name> [-d <domain-name>]...
```

(The difference is the path after the `-w` argument.)

For either type of site, re-run the site set-up script.
It will detect the key files,
and configure the site for TLS/HTTPS access,
including redirecting HTTP requests to HTTPS.

Rails:

```bash
sudo -E ./create-rails-app.sh <domain-name>...
sudo nginx -s reload
```

Static site:

```bash
sudo -E ./create-server-block.sh <domain-name>...
sudo nginx -s reload
```

Test renewal with:

```bash
sudo certbot renew --dry-run
```

## Testing TLS

Go to the [SSL test page](https://www.ssllabs.com/ssltest/)
to test that the TLS implementation is working.
You should get an A+ with the above set-up.

## Default Site

We redirect anything asking for the IP address of the server
to our home page.
To set that up,
go to the directory with all the scripts and run:

```bash
sudo ./create-default-server.sh
sudo nginx -s reload

```

## Reverse Proxy

(Experimental implementation.)
To create a reverse proxy to forward HTTPS requests to an HTTP-only site
(this works, but keep reading before you do it):

```bash
sudo gem install shared-infrastructure
sudo create-reverse-proxy <proxy-domain-name> <target-url>
```

This creates a reverse proxy accessible via HTTP.

The Let's Encrypt `certbot` program for getting certificates
expects a publicly accessible directory behind the `proxy-domain-name`.
A proxy normally doesn't have that,
and `create-reverse-proxy` doesn't create one.

One solutions is to create a certificate with multiple URLs
when configuring the original domain.
For example,
if the main site is `example.com`
but you want to reverse-proxy `https://search.example.com`
to another address,
you could create the site like this:

```bash
create-server-block example.com search.example.com
```

then get the certificate,
which will cover both domains.
Then create the reverse proxy like this:

```bash
create-reverse-proxy --certificate-domain example.com http://search.example.com
```

I thought this would fail
because the site is now using HTTPS,
so the `certbot` command wouldn't work,
but it does.

However,
it does fail because each site does indeed need to get the download.
So the reverse proxy needs to have a location that maps to `/.well-known`.
