# frozen_string_literal: true

module SharedInfrastructure
  module OutputHelpers
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
  end

  class Output < File
    def initialize(file_name, *args)
      if Output.root
        file_name = File.join(Output.root, file_name)
        FileUtils.mkdir_p(File.dirname(file_name))
      end
      super file_name, *args
    end

    class << self
      ##
      # Fake root. If block is given, change the root only for the duration
      # of the block. If no block is given, is the same as configure.
      def fake_root(root = nil)
        if block_given?
          begin
            save_root = Output.root
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
