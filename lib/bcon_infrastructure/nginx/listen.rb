# frozen_string_literal: true

module Nginx
  class Listen
    def initialize(port)
      @port = port
    end

    def to_s(level = 0)
      Lines.new("listen #{port};", "listen [::]:#{port};").format(level)
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
