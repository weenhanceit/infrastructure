#!/bin/bash
# Thanks to: http://sfviapgh.com/blog/2016/2/18/how-to-deploy-rails-with-aws-codedeploy

export RAILS_ENV=production
cd /var/www/<app location>
bundle install # --path vendor/bundle
bundle binstubs puma --path ./bin
bundle exec rake db:migrate
bundle exec rake assets:clobber
bundle exec rake assets:precompile
