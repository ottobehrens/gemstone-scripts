#!/usr/bin/ruby

require 'test/unit'
require 'Stone'

class StoneTestCase < Test::Unit::TestCase
  def setup
    @instance = Stone.new('wotto')
  end

  def test_start
    assert !@instance.isRunning
    @instance.start
    assert @instance.isRunning
  end

  def teardown
    @instance.stop
  end
end
