# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class StaticHttpsBuilderTest < Test
  StaticHttpsBuilder.include TestHelpers

  def test_https_server_block
    builder = StaticHttpsBuilder.new(HttpsServerBlock, Config.new("example.com"))
    assert_equal builder.expected_https_server_block, builder.server_block
  end
end
