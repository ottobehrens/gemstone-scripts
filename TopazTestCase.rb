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
    @topaz.commands(["status"])
    fail "Output is #{@topaz.mostRecentOutput}" if /^Current settings are\:/ !~ @topaz.mostRecentOutput
  end

  def test_login
    @topaz.commands(["set gems #{@stone.name} u DataCurator p swordfish", "login", "commit"])
    fail "Output is #{@topaz.mostRecentOutput}" if /^Successful commit/ !~ @topaz.mostRecentOutput
  end
end
