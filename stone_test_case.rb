#!/usr/bin/ruby

require 'rubygems'
require 'date'

require 'test/unit'
require 'flexmock/test_unit'
require 'stone'

require 'fileutils'
include FileUtils


class Stone
  include FlexMock::TestCase
  
  def override_runners(command_runner, topaz_runner)
    @command_runner = command_runner
    @topaz_runner = topaz_runner
  end
end

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

  def test_abstract
  end
end

class StoneUnitTestCase < StoneTestCase
  def notest_backup
    stone = Stone.create(TEST_STONE_NAME)
    mock_command_runner = flexmock('command')
    mock_topaz_runner = flexmock('topaz')

    log_number = "1313"

    mock_topaz_runner.should_receive(:commands).with("SystemRepository startNewLog").and_return("[4202 sz:0 cls: 74241 SmallInteger] #{log_number}").once.ordered
    mock_topaz_runner.should_receive(:commands).with("SystemRepository startCheckpointSync").once.ordered
    mock_topaz_runner.should_receive(:commands).with("System abortTransaction. SystemRepository fullBackupCompressedTo: '#{stone.backup_directory}/#{stone.name}_#{Date.today.strftime('%F')}.full.gz'").once.ordered
    mock_command_runner.should_receive(:run).with("tar zcf #{stone.backup_filename} #{stone.extend_backup_filename} #{stone.data_directory}/tranlog/tranlog#{log_number}.dbf").once.ordered
    
    stone.override_runners(mock_command_runner, mock_topaz_runner)
    stone.backup
  end
end

class StoneIntegrationTestCase < StoneTestCase

  def test_backup
    stone = Stone.create(TEST_STONE_NAME)
    rm stone.backup_filename if File.exist? stone.backup_filename
    stone.start
    stone.backup
    assert File.exist? stone.backup_filename
  end

  def test_netldi
    `stopnetldi`
    assert `gslist` !~ /^exists.*Netldi/
    GemStone.current.startnetldi
    assert `gslist` =~ /^exists.*Netldi/
    GemStone.current.stopnetldi
    assert `gslist` !~ /^exists.*Netldi/
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
