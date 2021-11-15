# frozen_string_literal: true

module Nginx
  ##
  # A class to format lines nicely in a file.
  class Lines < Array
    def initialize(*lines)
      @lines = Array(lines)
    end

    def format(level = 0)
      @lines.map { |x| Lines.indent(x, level) }.join("\n")
    end

    class << self
      def indent(s, level = 0)
        s.empty? ? s : (" " * level * 2) + s
      end
    end
  end
end
