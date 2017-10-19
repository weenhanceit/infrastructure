# frozen_string_literal: true

class StaticHttpBuilder
  def build
    File.open(@config.server_block_location, "w") do |f|
      f << server_block
    end
  end

  def initialize(server_block_class, config)
    @config = config
    @server_block_class = server_block_class
  end

  def server_block
    @server_block_class.new(@config).server_block
  end
end
