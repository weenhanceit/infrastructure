module Nginx
  ##
  # A class to format lines nicely in a file.
  class Lines < Array
    def initialize(*lines)
      @lines = Array(lines)
    end

    def format(level = 0)
      @lines.map { |x| x.empty? ? x : (" " * level * 2) + x }.join("\n")
    end
  end
end
