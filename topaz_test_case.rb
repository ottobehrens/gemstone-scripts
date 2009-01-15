#!/usr/bin/ruby

require 'topaz'
require 'stone'

require 'common_test_case'

class TopazTestCase < BaseTestCase
  def setup
    clear_stone(TEST_STONE_NAME)
    @stone = Stone.create(TEST_STONE_NAME)
    @stone.start
    @topaz = Topaz.new(@stone)
  end

  def test_single_command
    @topaz.commands(["status", "exit"])
    fail "Output is #{@topaz.output[1]}" if /^Current settings are\:/ !~ @topaz.output[1]
  end

  def test_login
    @topaz.commands(["set gems #{@stone.name} u DataCurator p swordfish", "login", "exit"])
    fail "Output is #{@topaz.output[2]}" if /^successful login/ !~ @topaz.output[2]
  end
  
  def test_fail
    assert_raises(TopazError) { @topaz.commands(["an invalid command"]) }
  end
end
