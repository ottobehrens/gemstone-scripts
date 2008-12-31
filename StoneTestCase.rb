#!/usr/bin/ruby

require 'test/unit'
require 'Stone'

class StoneTestCase < Test::Unit::TestCase
  TEST_STONE_NAME = 'testcase'

  def setup
    if GemStone.current.stones.include? TEST_STONE_NAME
     Stone.existing(TEST_STONE_NAME).stop.delete
    end
  end

  def notest_restart
    @instance = Stone.existing TEST_STONE_NAME
    @instance.start
    @instance.restart
    assert @instance.running?
    # restart can be a nop and this will still pass. How do I test it? Change a config & restart?
    @instance.stop
    @instance.restart
    assert @instance.running?
  end

  def notest_stop_not_running
    @instance = Stone.existing TEST_STONE_NAME
    @instance.stop
    assert !@instance.running?
    @instance.stop
    assert !@instance.running?
  end

  def notest_start_already_running
    @instance = Stone.existing TEST_STONE_NAME
    @instance.start
    assert @instance.running?
    @instance.start
    assert @instance.running?
  end

  def test_create_new
    assert !GemStone.current.stones.include?(TEST_STONE_NAME)
    stone = Stone.create(TEST_STONE_NAME)
    assert GemStone.current.stones.include?(TEST_STONE_NAME)
    stone.start
    assert stone.running?
    assert File.directory?(stone.logDirectory)
  end

  def test_create_config_file
    config_filename = "#{GemStone.current.config_directory}/#{TEST_STONE_NAME}.conf"
    assert ! (File.exist? config_filename)

    stone = Stone.new(TEST_STONE_NAME).createConfFile

    assert File.exists? config_filename
    assert GemStone.current.stones.include?(TEST_STONE_NAME)
    content = File.open(config_filename).readlines.join 
    assert content.include? "DBF_EXTENT_NAMES = #{stone.extent_filename}"
  end
end
