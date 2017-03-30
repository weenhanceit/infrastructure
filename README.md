# infrastructure
Build infrastructure for Weenhanceit projects

## Goals
* Host multiple sites easily on one VPS
* Replicable, so when we need to move an app to its own server, it's easy
* Easy deploys of apps
* Good notification of problems

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
* AWS has a deployment facility: https://aws.amazon.com/codedeploy/
* Travis can deploy to AWS via CodeDeploy
* Puppet plays with CodeDeploy, too
* Do the off-the-shelf deploy systems allow deploying multiple applications to the same server?
