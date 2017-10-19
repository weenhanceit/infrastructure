# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "bcon-infrastructure"
  s.version     = "0.0.1"
  s.date        = "2017-10-18"
  s.summary     = "Configure nginx and/or Puma for static sites and Rails apps."
  s.description = ""
  s.authors     = ["Larry Reid"]
  s.email       = "lcreid@jadesystems.ca"
  s.files       = [
    "lib/bcon_infrastructure.rb",
    "lib/bcon_infrastructure/config.rb",
    "lib/bcon_infrastructure/http_server_block.rb",
    "lib/bcon_infrastructure/https_server_block.rb",
    "lib/bcon_infrastructure/rails_builder.rb",
    "lib/bcon_infrastructure/reverse_proxy_http_server_block.rb",
    "lib/bcon_infrastructure/static_builder.rb",
    "lib/bcon_infrastructure/static_http_builder.rb",
    "lib/bcon_infrastructure/static_https_builder.rb"
  ]
  s.executables << ["create-server-block", "create-rails-app"]
  s.homepage    = "https://github.com/weenhanceit/infrastructure"
  s.license     = "MIT"
end
