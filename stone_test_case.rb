#!/usr/bin/ruby

require 'stone'

require 'rubygems'
require 'common_test_case'
require 'date'

require 'test/unit'

# To get to FileUtils.sh
require 'rake'
verbose(false)

class StoneTestCase < BaseTestCase
  TEST_STONE_NAME = 'testcase'

  def setup
    clear_stone(TEST_STONE_NAME)
  end

  def test_abstract
  end
end

class StoneUnitTestCase < StoneTestCase
  def test_backup
    stone = Stone.create(TEST_STONE_NAME)
    mock_topaz_runner = flexmock('topaz')
    partial_mock_stone = flexmock(stone)

    log_number = "1313"

    mock_topaz_runner.should_receive(:commands).with(/SystemRepository startNewLog/).and_return(["[4202 sz:0 cls: 74241 SmallInteger] #{log_number}"]).once.ordered
    mock_topaz_runner.should_receive(:commands).with(/System startCheckpointSync/).once.ordered
    expected_backup_path = "#{stone.backup_directory}/#{stone.name}_#{Date.today.strftime('%F')}.full.gz"
    mock_topaz_runner.should_receive(:commands).with(/System abortTransaction. SystemRepository fullBackupCompressedTo: '#{expected_backup_path}'/).once.ordered
    partial_mock_stone.should_receive(:log_sh).with("tar zcf #{stone.backup_filename} #{stone.extend_backup_filename} #{stone.data_directory}/tranlog/tranlog#{log_number}.dbf").once.ordered
    
    stone.override_topaz_runner(mock_topaz_runner)
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

  def test_destroy
    stone = Stone.create(TEST_STONE_NAME)
    stone.start
    assert_raises(RuntimeError) { stone.destroy! }
    stone.stop
    stone.destroy!
    assert ! (File.exist? stone.extent_directory)
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