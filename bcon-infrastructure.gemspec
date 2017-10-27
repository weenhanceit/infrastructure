# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "bcon-infrastructure"
  s.version     = "0.0.2"
  s.date        = "2017-10-26"
  s.summary     = "Configure nginx, systemd, and/or Puma"
  s.description = %(For static sites, Rails apps, and reverse proxies.
)
  s.authors     = ["Larry Reid"]
  s.email       = "lcreid@jadesystems.ca"
  s.files       = [
    "lib/bcon_infrastructure.rb",
    "lib/bcon_infrastructure/nginx/nginx.rb",
    "lib/bcon_infrastructure/nginx/server_block.rb",
    "lib/bcon_infrastructure/nginx/server.rb",
    "lib/bcon_infrastructure/nginx/lines.rb",
    "lib/bcon_infrastructure/nginx/listen.rb",
    "lib/bcon_infrastructure/nginx/location.rb",
    "lib/bcon_infrastructure/nginx/site.rb",
    "lib/bcon_infrastructure/nginx/builder.rb",
    "lib/bcon_infrastructure/runner/base.rb",
    "lib/bcon_infrastructure/runner/reverse_proxy.rb",
    "lib/bcon_infrastructure/runner/static_site.rb",
    "lib/bcon_infrastructure/systemd/systemd.rb",
    "lib/bcon_infrastructure/systemd/rails.rb",
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
