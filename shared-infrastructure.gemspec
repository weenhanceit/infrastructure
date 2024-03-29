# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "shared_infrastructure/version"

Gem::Specification.new do |s|
  s.name        = "shared-infrastructure"
  s.version     = SharedInfrastructure::VERSION
  s.summary     = "Configure nginx, systemd, and/or Puma"
  s.description = %(For static sites, Rails apps, and reverse proxies.
)
  s.authors     = ["Larry Reid"]
  s.email       = "lcreid@jadesystems.ca"
  s.files       = [
    "lib/shared_infrastructure.rb",
    "lib/shared_infrastructure/domain.rb",
    "lib/shared_infrastructure/output.rb",
    "lib/shared_infrastructure/nginx/nginx.rb",
    "lib/shared_infrastructure/nginx/server_block.rb",
    "lib/shared_infrastructure/nginx/server.rb",
    "lib/shared_infrastructure/nginx/lines.rb",
    "lib/shared_infrastructure/nginx/listen.rb",
    "lib/shared_infrastructure/nginx/location.rb",
    "lib/shared_infrastructure/nginx/upstream.rb",
    "lib/shared_infrastructure/nginx/builder.rb",
    "lib/shared_infrastructure/nginx/accel.rb",
    "lib/shared_infrastructure/runner/base.rb",
    "lib/shared_infrastructure/runner/reverse_proxy.rb",
    "lib/shared_infrastructure/runner/static_site.rb",
    "lib/shared_infrastructure/runner/rails.rb",
    "lib/shared_infrastructure/systemd/systemd.rb",
    "lib/shared_infrastructure/systemd/rails.rb",
    "lib/shared_infrastructure/version.rb",
    "bin/create-rails-app",
    "bin/create-reverse-proxy",
    "bin/create-server-block"
  ]
  s.executables.concat(%w[
                         create-server-block
                         create-rails-app
                         create-reverse-proxy
                       ])
  s.homepage    = "https://github.com/weenhanceit/infrastructure"
  s.license     = "MIT"
end
