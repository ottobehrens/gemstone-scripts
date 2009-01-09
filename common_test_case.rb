require 'test/unit'
require 'flexmock/test_unit'

class BaseTestCase < Test::Unit::TestCase
  def clear_stone(stone_name)
    if GemStone.current.stones.include? stone_name
      stone = Stone.existing(stone_name)
      stone.stop
      rm stone.system_config_filename
      rm_rf stone.data_directory
    end
  end
end

class Stone
  include FlexMock::TestCase
  
  def override_topaz_runner(topaz_runner)
    @topaz_runner = topaz_runner
  end
end