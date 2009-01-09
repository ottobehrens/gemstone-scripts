#!/usr/bin/ruby

require 'stone'
require 'wonka'

require 'rubygems'
require 'date'

require 'common_test_case'
require 'test/unit'
require 'rake'
verbose(false)

class WonkaUnitTestCase < BaseTestCase
  TEST_STONE_NAME = 'testcase'

  def setup
    clear_stone(TEST_STONE_NAME)
  end

  def test_bootstrap_deployer
    stone = WonkaStone.create(TEST_STONE_NAME)
    mock_topaz_runner = flexmock('topaz')
    mock_topaz_runner.should_receive(:commands).with(/input #{Wonka.package_directory}\/Deployer.gs/).once.ordered
    stone.override_topaz_runner(mock_topaz_runner)

    stone.bootstrap
  end
end
