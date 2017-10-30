# frozen_string_literal: true

module Nginx
  class Upstream
    def initialize(domain_name)
      @domain_name = domain_name
    end

    def to_s(level = 0)
      Lines.new(
        "upstream #{domain_name} {",
        Lines.indent("server unix:///tmp/#{domain_name}.sock fail_timeout=0;", 1),
        "}"
      ).format(level)
    end

    attr_reader :domain_name
  end
end
