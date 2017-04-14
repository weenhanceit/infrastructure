#!/bin/bash
# Thanks to: http://sfviapgh.com/blog/2016/2/18/how-to-deploy-rails-with-aws-codedeploy

export RAILS_ENV=production
cd /var/www/<app location>
# need to set up the database (the user)
# need rails db:create the first time
bundle install # --path vendor/bundle
bundle binstubs puma --path ./bin
rails db:migrate
rails assets:clobber
rails assets:precompile
