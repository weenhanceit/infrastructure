# frozen_string_literal: true

class HttpServerBlock
  def server_block
    start_server_block + %(  listen 80;
  listen [::]:80;
) + end_server_block
  end

  def initialize(config)
    @config = config
  end

  private

  def end_server_block
    %(#{location}
}
)
  end

  def location
    %(
  location / {
    try_files $uri $uri/ =404;
  })
  end

  def root
    %(
  root #{@config.root_directory};
  index index.html index.htm;
)
  end

  def start_server_block
    %(server {
  server_name #{@config.domain_names};
#{root}
)
  end
end
