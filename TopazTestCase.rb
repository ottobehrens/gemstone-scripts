#!/usr/bin/ruby

require 'test/unit'
require 'Topaz'
require 'Stone'

class TopazTestCase < Test::Unit::TestCase
  def setup
    @stone = Stone.existing('otto')
    @stone.start
    @topaz = Topaz.new(@stone)
  end

  def test_singleCommand
    @topaz.commands(["status", "exit"])
    fail "Output is #{@topaz.output[1]}" if /^Current settings are\:/ !~ @topaz.output[1]
  end

  def test_login
    @topaz.commands(["set gems #{@stone.name} u DataCurator p swordfish", "login", "exit"])
    fail "Output is #{@topaz.output[2]}" if /^successful login/ !~ @topaz.output[2]
  end
end
