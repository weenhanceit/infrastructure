#!/bin/bash

fake_root=/tmp/test-server-block-$$.out

function setup() {
  rm -rf $fake_root
}

function assert() {
  eval $1 || echo $2
}

# Test basic usage HTTP
setup
create-server-block -f $fake_root example.com

# Test basic usage HTTPS
setup
create-server-block -f $fake_root -p 443 example.com
