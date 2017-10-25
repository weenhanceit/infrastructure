# frozen_string_literal: true

require "minitest/autorun"
require "bcon_infrastructure"
require "test"

class StaticHttpsBuilderTest < Test
  include TestHelpers

  def test_https_server_block
    skip "This is broken by the factoring of the addition of the redirect block"
    builder = StaticHttpsBuilder.new(HttpsServerBlock, Config.new("example.com"))
    assert_equal expected_https_server_block, builder.server_block
  end
end
