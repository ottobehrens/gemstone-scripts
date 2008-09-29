#!/usr/bin/ruby

require 'test/unit'
require 'Topaz'
require 'Stone'

class TopazTestCase < Test::Unit::TestCase
  def setup
    @stone = Stone.new('otto')
    @stone.start
    @topaz = Topaz.new(@stone)
  end

  def test_singleCommand
    @topaz.commands(["status\n"])
    fail "Output is #{@topaz.mostRecentOutput}" if /^Current settings are\:/ !~ @topaz.mostRecentOutput
  end

  def teardown
    @stone.stop
  end
end
