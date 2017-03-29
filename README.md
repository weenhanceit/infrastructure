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
* `nginx` because it's light weight
* Postgres because it's full featured and more reliably open source
* People seem to use `nginx` to proxy to different sites, but then something behind it?
* Heroku uses Puma. Is Puma all we need to serve Rails apps at our scale?
