#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), "..", 'stone')
require File.join(File.dirname(__FILE__), "..", 'topaz')

require File.join(File.dirname(__FILE__), 'common_test_case')

class TopazTestCase < BaseTestCase
  def setup
    super
    @stone = Stone.create(TEST_STONE_NAME)
    @stone.start
    @topaz = Topaz.new(@stone)
  end

  def test_simple_commands
    @topaz.commands(["status", "exit"])
    fail "Output is #{@topaz.output_of_command(0)}" if /^Current settings are:/ !~ @topaz.output_of_command(0).line(2)
  end

  def test_login
    login_and_run([])
    fail "Output is #{@topaz.output_of_command(1)}" if /^successful login/ !~ @topaz.output_of_command(1).line(7)
  end
  
  def test_nested_commands
    login_and_run(["level 0", ["printit", "| x |", "x := 6 + 4", "%"]])
    fail "Output is #{@topaz.output_of_command(2)}" if /^10/ !~ @topaz.output_of_command(2).line(5)
  end

  def test_error
    begin
      login_and_run([["run", "0 error: 'error'", "%"]])
    rescue TopazError => error
      assert(error.output.include?('Arg 2: error'))
      return
    end
    fail 'Error not tripped'
  end

  def test_fail
    assert_raises(TopazError) { @topaz.commands(["an invalid command"]) }
  end

  def login_and_run(commands)
    @topaz.commands(["set gems #{@stone.name} u DataCurator p swordfish", "login"] << commands << "exit")
  end
end
