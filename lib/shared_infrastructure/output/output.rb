# frozen_string_literal: true

module SharedInfrastructure
  module Output
    class Output
      def initialize(file)
        @io = if file.is_a?(IO) || file.is_a?(StringIO)
                file
              else
                File.open(File.join([SharedInfrastructure::Output.root, file].compact), "w")
              end
      end

      # @param indent_string The string to use for indenting. Defaults to the
      # first character of `s`.
      # @param amount The number of `indent_string` to put at the start of each
      #   line. Default: 2.
      # @param indent_empty_lines Don't indent empty lines unless this is true.
      def indent(s, amount = 2, indent_string = nil, indent_empty_lines = false)
        indent_string = indent_string || s[/^[ \t]/] || " "
        re = indent_empty_lines ? /^/ : /^(?!$)/
        s.gsub(re, indent_string * amount)
      end

      def print(s)
        io << s
      end

      private

      attr_accessor :io
    end

    class << self
      ##
      # Fake root. If block is given, change the root only for the duration
      # of the block. If no block is given, is the same as configure.
      def fake_root(root = nil)
        if block_given?
          begin
            save_root = SharedInfrastructure::Output.root
            fake_root(root)
            result = yield
          ensure
            fake_root(save_root)
            result
          end
        else
          self.root = root
        end
      end

      attr_accessor :root
    end
  end
end
