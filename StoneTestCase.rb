#!/usr/bin/ruby

require 'test/unit'
require 'Stone'

class StoneTestCase < Test::Unit::TestCase
  def setup
    @instance = Stone.new('otto')
  end

  def test_restart
    @instance.start
    @instance.restart
    assert @instance.running?
    # restart can be a nop and this will still pass. How do I test it? Change a config & restart?
    @instance.stop
    @instance.restart
    assert @instance.running?
  end

  def test_stop_not_running
    @instance.stop
    assert !@instance.running?
    @instance.stop
    assert !@instance.running?
  end

  def test_start_already_running
    @instance.start
    assert @instance.running?
    @instance.start
    assert @instance.running?
  end
end
