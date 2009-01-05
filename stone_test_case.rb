#!/usr/bin/ruby

require 'test/unit'
require 'stone'

require 'fileutils'
include FileUtils

class StoneTestCase < Test::Unit::TestCase
  TEST_STONE_NAME = 'testcase'

  def setup
    if GemStone.current.stones.include? TEST_STONE_NAME
      stone = Stone.existing(TEST_STONE_NAME)
      stone.stop
      rm stone.system_config_filename
      rm_rf stone.data_directory
    end
  end

  def test_create_new
    assert !GemStone.current.stones.include?(TEST_STONE_NAME)
    stone = Stone.create(TEST_STONE_NAME)
    assert GemStone.current.stones.include?(TEST_STONE_NAME)
    stone.start
    assert stone.running?
    assert File.directory?(stone.log_directory)
  end

  def test_existing_stone_retrieve
    Stone.create TEST_STONE_NAME
    stone = Stone.existing TEST_STONE_NAME
    assert_not_nil stone
    stone.start
    assert stone.running?
  end

  def test_restart
    stone = Stone.create TEST_STONE_NAME
    stone.start
    stone.restart
    assert stone.running?
    # restart can be a nop and this will still pass. How do I test it? Change a config & restart?
    stone.stop
    stone.restart
    assert stone.running?
  end

  def test_stop_not_running
    stone = Stone.create TEST_STONE_NAME
    stone.stop
    assert !stone.running?
    stone.stop
    assert !stone.running?
  end

  def test_start_already_running
    stone = Stone.create TEST_STONE_NAME
    stone.start
    assert stone.running?
    stone.start
    assert stone.running?
  end

  def test_create_config_file
    config_filename = "#{GemStone.current.config_directory}/#{TEST_STONE_NAME}.conf"
    assert ! (File.exist? config_filename)

    stone = Stone.new(TEST_STONE_NAME, GemStone.current).create_config_file

    assert File.exists? config_filename
    assert GemStone.current.stones.include?(TEST_STONE_NAME)

    content = File.open(config_filename).readlines.join 
    assert content.include? "DBF_EXTENT_NAMES = #{stone.extent_filename}"
    assert content.include? "DBF_SCRATCH_DIR = #{stone.scratch_directory}"
    assert content.include? "STN_TRAN_LOG_DIRECTORIES = #{stone.tranlog_directories.join(",")}"
  end
end
