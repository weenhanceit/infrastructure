# Infrastructure
Set up infrastructure for Weenhanceit projects.

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
This document assumes you've already set up a server,
and a Postgres instance.

## Common First Steps
These steps are necessary whether you want to deploy
a static web site
or a Rails application.

1. Log in to the server via SSH
```
    ssh -i ~/.ssh/weita.pem ubuntu@URL-of-server
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
This step is only necessary after you first set up the server.
It installs additional software needed on the server.
```
./build.sh
```

Also install the gem:
```
sudo gem install specific_install --no-document
sudo gem specific_install shared-infrastructure -l https://github.com/weenhanceit/infrastructure.git -b ruby
```

### Creating Users
Here's how to create named users with sudo privileges on the server.
These instructions work if your desktop is running Ubuntu.

1. Create a key pair if you don't already have one. Accept the defaults,
and don't enter a pass phrase:
```
    mkdir ~/.ssh
    chmod 700 ~/.ssh  
    ssh-keygen -t rsa
```
  This leaves a key pair in `~/.ssh/id_rsa` (the private key)
  and `~/.ssh/id_rsa.pub` (the public key).

2. Obtain a copy of the user creation script:
```
    wget https://github.com/weenhanceit/infrastructure/raw/master/basic-app-server/create-user.sh
```
3. Run the user creation script:
```
    ./create-user -k existing-user-key-file username ~/.ssh/id_rsa.pub ubuntu@ec2-server-address
```
  It's important to understand which key file is which.
  `existing-user-key-file` is the private key that you obtained
  from Amazon when you created the instance.
  `~/.ssh/id_rsa.pub` is the *public* key file
  from the key pair you just generated.

## Creating a Static Web Site
This sets up an Nginx server block for a given domain name.
In all the examples that follow,
replace `domain-name` with your domain name.
```
sudo bundle exec create-server-block domain-name
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

### Set the Rails Environment Variables
The Rails instance expects certain environment variables to be set.

For the following, you get the "secret-key-base" by doing `rails secret`.
[TODO: `rails secret` assumes you have an application set up, which you might not have at this point.]
The "database-username" and "database-password" can be whatever you choose them to be.
```
export SECRET_KEY_BASE=secret-key-base
export DATABASE_USERNAME=database-username
export DATABASE_PASSWORD=database-password
export EMAIL_PASSWORD=email-password
```

### Create the Rails Application
If the application does *not* use `send_file` to ask Nginx to send private files:
```
sudo -E bundle exec create-rails-app domain-name
```
If the application uses uses `send_file` to ask Nginx to send private files, add the `-a` flag:
```
sudo -E bundle exec create-rails-app -a location
```
Where `location` is the folder in which the private documents are kept (e.g. `/private`).

Don't forget the `-E` to `sudo`. It causes the environment variables to be passed to the script.
If you forget to use the `-a` flag,
you can safely re-run this script later with the flag.

The above will tell you how to get a certificate for the site,
but you can't do that yet.
You need to deploy the application the first time,
so the directories get created.

Finally, set up the database:
```
export DATABASE=database
./create-db-user.sh
```
The last step above will ask you for the password for the `root` user in the Postgres database.

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
```
sudo ./create-redis-instance.sh domain-name
```
This creates the configuration file
and necessary directories
to run an instance of Redis for the application.
A `systemd` unit file is created,
so you can start the instance of Redis using:
```
sudo systemctl start redis.domain-name
```
and stop the instance of Redis using:
```
sudo systemctl stop redis.domain-name
```
You can see the status of the instance of Redis using:
```
sudo systemctl status redis.domain-name
```
The Redis log messages are written to `/var/log/syslog`.

The create script sets up the Redis instance to automatically start
when the server starts,
but it doesn't start the instance when it's first created.
Remember to start the instance with:
```
sudo systemctl start redis.domain-name
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
```
sudo -E ./create-sidekiq-instance.sh domain-name
```
(Don't forget the `-E` to `sudo`.
It causes the environment variables to be passed to the script.)
This creates the configuration file
and necessary directories
to run an instance of Sidekiq for the application.
A `systemd` unit file is created,
so you can start the instance of Sidekiq using:
```
sudo systemctl start sidekiq.domain-name
```
and stop the instance of Sidekiq using:
```
sudo systemctl stop sidekiq.domain-name
```
You can see the status of the instance of Sidekiq using:
```
sudo systemctl status sidekiq.domain-name
```
The Sidekiq log messages are written to `/var/log/syslog`.

The create script sets up the Sidekiq instance to automatically start
when the server starts,
but it doesn't start the instance when it's first created.
Remember to start the instance with:
```
sudo systemctl start sidekiq.domain-name
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

```
sudo certbot certonly --webroot -w /var/www/domain_name/html/public -d domain_name [-d domain_name]...
```

For static sites,
run this command and answer its questions to obtain and install certificates:

```
sudo certbot certonly --webroot -w /var/www/domain_name/html -d domain_name [-d domain_name]...
```

(The difference is the path after the `-w` argument.)

For either type of site, re-run the site set-up script.
It will detect the key files,
and configure the site for TLS/HTTPS access,
including redirecting HTTP requests to HTTPS.

Rails:

```
sudo -E ./create-rails-app.sh domain_name...
sudo nginx -s reload
```

Static site:

```
sudo -E ./create-server-block.sh domain_name...
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

## Default Site
We redirect anything asking for the IP address of the server
to our home page.
To set that up,
go to the directory with all the scripts and run:
```
sudo ./create-default-server.sh
sudo nginx -s reload

```

## Reverse Proxy
(Experimental implementation.)
To create a reverse proxy to forward HTTPS requests to an HTTP-only site
(this works, but keep reading before you do it):
```
sudo gem install shared-infrastructure
sudo create-reverse-proxy proxy-domain-name target-url
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
```
create-server-block example.com search.example.com
```
then get the certificate,
which will cover both domains.
Then create the reverse proxy like this:
```
create-reverse-proxy --certificate-domain example.com http://search.example.com
```
I thought this would fail
because the site is now using HTTPS,
so the `certbot` command wouldn't work,
but it does.

However,
it does fail because each site does indeed need to get the download.
So the reverse proxy needs to have a location that maps to `/.well-known`.
