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
4. Change to the scripts directory to save some typing:
```
    cd infrastructure-master/basic-app-server
```

## One-Time Server Set-Up
This step is only necessary after you first set up the EC2 instance.
It installs additional software needed on the server.
```
./build.sh
```

## Creating a Static Web Site
This sets up an Nginx server block for a given domain name.
In all the examples that follow,
replace `domain-name` with your domain name.
```
sudo ./create-server-block.sh domain-name
```
The root directory of the static web site files is `/var/www/domain-name/html`.

Now you can deploy the static web site. [TODO: How to deploy.]

Once deployed, remember to reload the Nginx configuration:
```
sudo nginx -s reload
```

## Creating a Rails Application
This sets up:

* An Nginx server block for a given domain name. The server block proxies via a domain socket to Puma
* A `systemd` service file that runs an instance of Puma
receiving requests on the same domain socket.
```
export SECRET_KEY_BASE=secret-key-base
export DATABASE_USERNAME=database-username
export DATABASE_PASSWORD=database-password
sudo -E ./create-rails-app.sh domain-name
export DATABASE=database
./create-db-user.sh
```
The last step above will ask you for the password for the `root` user in the Postgres database.

Don't forget the `-E` to `sudo`. It allows the environment variables to be passed to the script.

The root directory of the Rails application is `/var/www/domain-name/html`.

Now you can deploy the Rails app.
Note that before you deploy,
you have to do `bundle binstubs puma`
in your Rails app, and then commit the `bin` directory to Github. [TODO: How to deploy.]

NOTE: Currently the first deploy will fail,
since the database doesn't exist.
You have to manually do `rails db:setup`
after getting the application code to the server.

Once deployed, remember to reload the Nginx configuration:
```
sudo nginx -s reload
```
The deployment script should start the Puma service.
Check Puma's status with:
```
sudo systemctl status domain-name
```
If it's not running, try to restart it with:
```
sudo systemctl restart domain-name
```

## TLS (formerly SSL)
All Internet traffic should be encrypted,
if you want to be a good citizen.
We get certificates from [Let's Encrypt](https://letsencrypt.org),
using the [EFF's Certbot](https://certbot.eff.org).
You should read the documentation for both of those
before you run the scripts to create HTTPS sites.

Certbot needs a running web server,
and these scripts require that the web server be responding to port 80.
So you have to do the above installation steps
to create the site for HTTP
before proceeding with the rest of this section.

[Currently TLS is scripted for Rails sites only.]

Run this command and answer its questions to obtain and install certificates:

```
sudo certbot certonly --webroot -w /var/www/domain_name/html/public -d domain_name [-d domain_name]...
```

Then, re-run the site set-up script.
It will detect the key files,
and configure the site for TLS/HTTPS access,
including redirecting HTTP requests to HTTPS.

```
sudo -E ./create-rails-app.sh domain_name...
sudo nginx -s reload
```

Test renewal with:

```
sudo certbot renew --dry-run
```

## Testing TLS
Go to the [SSL test page](https://www.ssllabs.com/ssltest/)
to test that the TLS implementation is working.
You should get an A+ with the above set-up.
