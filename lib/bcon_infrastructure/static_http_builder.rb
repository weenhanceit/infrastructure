# frozen_string_literal: true

class StaticHttpBuilder
  def build
    File.open(@config.server_block_location, "w") do |f|
      f << @server_block_class.new(@config).to_s
    end
  end

  def initialize(server_block_class, config)
    @config = config
    @server_block_class = server_block_class
  end
end
