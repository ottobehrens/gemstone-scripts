require 'rubygems'
require 'test/unit'
require 'flexmock/test_unit'

# To get to FileUtils.sh
require 'rake'
verbose(false)

require 'date'

class BaseTestCase < Test::Unit::TestCase
  def clear_stone(stone_name)
    if GemStoneInstallation.current.stones.include? stone_name
      stone = Stone.existing(stone_name)
      stone.stop
      rm stone.system_config_filename
      rm_rf stone.data_directory
    end
  end

  def test_abstract
  end
end
