# infrastructure
Build infrastructure for Weenhanceit projects

## Goals
* Host multiple sites easily on one VPS
* Replicable, so when we need to move an app to its own server, it's easy
* Easy deploys of apps
* Good notification of problems
* Sort out what to do about e-mail

## Architecture
An Amazon EC2 server and an Amazon RDS instance. Use Elastic Beanstalk to deploy (TBC).

## Research
* Confirm that Elastic Beanstalk will work to deploy multiple applications to the same EC2 server. It seems like Elastic Beanstalk for Ruby includes Puma and Nginx, so they might be restricting the configuration options

## Overview
* Amazon EC2 server
  * There is a Canadian zone
  * We don't want to experiment with small providers at this time
  * Lots of options for sizing and scaling
* What's the storage model? On the one I had, I just deployed everything to the server, but a lot of what I read seems to assume you have your application sitting on S3 somewhere
* `nginx` because it's light weight
* Postgres because it's full featured and more reliably open source
* People seem to use `nginx` to proxy to different sites, but then something behind it?
* Heroku uses Puma. Is Puma all we need to serve Rails apps at our scale?
* Between Puppet, Chef, and Ansible, I'm still inclined to Puppet. Which should we use?

## Notes
* There's a nice summary of what you need to do to set up a server and deploy a Rails app to it here: https://gorails.com/deploy/ubuntu/16.04
* There's a nice summary of nginx configuration for multiple sites/domains (they call them "server blocks", like Apache's "virtual hosts"): https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-server-blocks-virtual-hosts-on-ubuntu-14-04-lts
* AWS has a deployment facility: https://aws.amazon.com/codedeploy/
* Travis can deploy to AWS via CodeDeploy
* Puppet plays with CodeDeploy, too
* Amazon Elastic Beanstalk seems to be almost Heroku-like. A little hard to spec pricing, since it seems to scale automatically for you
* Do the off-the-shelf deploy systems allow deploying multiple applications to the same server?
* An advantage of rolling our own is that we can test on local machines, e.g. my basement server
* Consider Amazon RDS for the database. Price is reasonable, and they do all the work
 * This takes us away from the "roll your own" model, or perhaps makes another way that "roll your own" has to track Amazon

## Costs
* You can buy "Convertible Reserved Instances" for three-year periods, and you can upgrade them by paying the difference to the bigger platform
 * Not available for Postgres RDS in Canada at the moment, at least

## Access and Security
* Everyone who has access has to use two-factor authentication with Amazon. This can be enforced 
* Setting up different user accounts for different application installations?
 * Account itself
 * Environment variables (e.g. the secrets)
* Certificates via Amazon are free: https://aws.amazon.com/certificate-manager/?hp=tile&so-exp=below
* Need to make sure the path between the app server and the database is secure

## Implementation Notes
* Each application should have its own deployment user and group
* Each application should have its own run user, distinct from the deploy user if that makes sense
* Puppet maintains nginx and Postgres installs, and any other binary installs (e.g. PDFtk)
* Puppet maintains users?
* It's nice to say that the "roll your own" approach allows us to test locally, but it also means we have to set up the local as if it were an AWS instance, meaning public key logons, etc.
* You can use Amazon spot instances to test, so roll your own may not have much of an advantage
