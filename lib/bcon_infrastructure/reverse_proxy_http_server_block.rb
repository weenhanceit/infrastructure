# frozen_string_literal: true

class ReverseProxyHttpServerBlock < HttpServerBlock
  def location
    %(
  location @#{@config.domain_name} {
    proxy_pass #{@config.proxy_url};
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;
  })
  end

  def root; end
end
