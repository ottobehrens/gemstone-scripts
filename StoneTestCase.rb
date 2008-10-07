#!/usr/bin/ruby

require 'test/unit'
require 'Stone'

class StoneTestCase < Test::Unit::TestCase
  def test_restart
    @instance = Stone.existing('otto')
    @instance.start
    @instance.restart
    assert @instance.running?
    # restart can be a nop and this will still pass. How do I test it? Change a config & restart?
    @instance.stop
    @instance.restart
    assert @instance.running?
  end

  def test_stop_not_running
    @instance = Stone.existing('otto')
    @instance.stop
    assert !@instance.running?
    @instance.stop
    assert !@instance.running?
  end

  def test_start_already_running
    @instance = Stone.existing('otto')
    @instance.start
    assert @instance.running?
    @instance.start
    assert @instance.running?
  end

  def test_create_new
    begin
      assert !Stone.definedInstances.include?('doesNotExist')
      @instance = Stone.create('doesNotExist')
      assert Stone.definedInstances.include?('doesNotExist')
      assert @instance.running?
      assert File.directory?(@instance.logDirectory)
    ensure
      @instance.delete
      assert !@instance.running?
      assert !Stone.definedInstances.include?('doesNotExist')
    end
  end
end
