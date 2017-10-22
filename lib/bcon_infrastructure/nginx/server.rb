# frozen_string_literal: true

module Nginx
  ##
  # The server_name line of a server block.
  class Server
    def initialize(domain_name)
      @domain_name = domain_name
    end

    def to_s(level = 0)
      "#{' ' * level * 2}server_name #{domain_name} www.#{domain_name};"
    end

    attr_reader :domain_name
  end
end
