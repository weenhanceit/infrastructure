# frozen_string_literal: true

module Nginx
  class Listen
    def initialize(port)
      @port = port
    end

    def to_s(level = 0)
      [
        "listen #{port};",
        "listen [::]:#{port};"
      ].map { |x| x.empty? ? x : (" " * level * 2) + x }.join("\n")
    end

    private

    attr_reader :port
  end

  class ListenHttp < Listen
    def initialize
      super 80
    end
  end

  class ListenHttps < Listen
    def initialize
      super 443
    end
  end
end
