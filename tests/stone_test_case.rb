#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), "..", 'stone')
require File.join(File.dirname(__FILE__), 'common_test_case')

class StoneTestCase < BaseTestCase
  def setup
    clear_stone(TEST_STONE_NAME)
  end
end

class StoneUnitTestCase < StoneTestCase
  def test_backup
    stone = Stone.create(TEST_STONE_NAME)
    partial_mock_stone = flexmock(stone)

    log_number = "1313"

    partial_mock_stone.should_receive(:topaz_commands).with(/SystemRepository startNewLog/).and_return(["[4202 sz:0 cls: 74241 SmallInteger] #{log_number}"]).once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(/System startCheckpointSync/).once.ordered
    expected_backup_directory = "#{stone.backup_directory}/#{stone.name}_#{Date.today.strftime('%F')}.full.gz"
    partial_mock_stone.should_receive(:topaz_commands).with(/System abortTransaction. SystemRepository fullBackupCompressedTo: '#{expected_backup_directory}'/).once.ordered
    partial_mock_stone.should_receive(:log_sh).with("tar zcf #{stone.backup_filename_for_today} #{stone.extent_backup_filename_for_today} #{stone.data_directory}/tranlog/tranlog#{log_number}.dbf").once.ordered
    
    stone.backup
  end

  def test_restore
    stone = Stone.create(TEST_STONE_NAME)
    partial_mock_stone = flexmock(stone)
    
    partial_mock_stone.should_receive(:log_sh).with("tar -C '#{stone.backup_directory}' -zxf '#{stone.backup_filename_for_today}'").once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(/SystemRepository restoreFromBackup: '#{stone.extent_backup_filename_for_today}'/).once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(/SystemRepository restoreFromCurrentLogs/).and_return('Restore from transaction log(s) succeeded').once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(/SystemRepository commitRestore/).and_return('commitRestore succeeded').once.ordered

    stone.restore_latest_backup
  end
end

class StoneIntegrationTestCase < StoneTestCase

  def test_backup
    stone = Stone.create(TEST_STONE_NAME)
    remove_previous_backup_files(stone)
    stone.start
    stone.backup
    assert File.exist? stone.backup_filename_for_today
  end

  def test_restore
    stone = Stone.create(TEST_STONE_NAME)
    stone.start
    add_restore_worked_method(stone)
    remove_previous_backup_files(stone)
    stone.backup
    stone.restore_latest_backup
    stone.run_topaz_command('String restoreWorked')
  end

  def test_netldi
    `stopnetldi`
    assert `gslist` !~ /^exists.*Netldi/
    GemStoneInstallation.current.startnetldi
    assert `gslist` =~ /^exists.*Netldi/
    GemStoneInstallation.current.stopnetldi
    assert `gslist` !~ /^exists.*Netldi/
  end

  def test_create_new
    assert !GemStoneInstallation.current.stones.include?(TEST_STONE_NAME)
    stone = Stone.create(TEST_STONE_NAME)
    assert GemStoneInstallation.current.stones.include?(TEST_STONE_NAME)
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
    config_filename = "#{GemStoneInstallation.current.config_directory}/#{TEST_STONE_NAME}.conf"
    assert ! (File.exist? config_filename)

    stone = Stone.new(TEST_STONE_NAME, GemStoneInstallation.current).create_config_file

    assert File.exists? config_filename
    assert GemStoneInstallation.current.stones.include?(TEST_STONE_NAME)

    content = File.open(config_filename).readlines.join 
    assert content.include? "DBF_EXTENT_NAMES = #{stone.extent_filename}"
    assert content.include? "DBF_SCRATCH_DIR = #{stone.scratch_directory}"
    assert content.include? "STN_TRAN_LOG_DIRECTORIES = #{stone.tranlog_directories.join(",")}"
  end

  private
  
  def remove_previous_backup_files(stone)
    rm stone.extent_backup_filename_for_today if File.exist? stone.extent_backup_filename_for_today
    rm stone.backup_filename_for_today if File.exist? stone.backup_filename_for_today
  end

  def add_restore_worked_method(stone)
    # Temp, until a stone is probable new'ed
    stone.run_topaz_command('GsPackageLibrary installPackage: (GsPackageLibrary createPackageNamed: #SessionMethods). System commitTransaction.')

    stone.topaz_commands([
                          'set class String', 
                          'set category for-integration-testing',
                          ['classmethod:',
                           'restoreWorked',
                           " ^ 'yay restore worked'",
                           '%'].join("\n"),
                          'commit'
                         ])
  end
end
