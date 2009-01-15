require 'common_test_case'
require 'glass_stone'

class GlassStoneTestCase < BaseTestCase
  def setup
    clear_stone(TEST_STONE_NAME)
  end
end

class GlassStoneUnitTestCase < GlassStoneTestCase
  def test_bootstrap
    stone = GlassStone.new(TEST_STONE_NAME, GemStoneInstallation.current)
    partial_mock_stone = flexmock(stone)

    partial_mock_stone.should_receive(:topaz_commands).with(/UserGlobals at: #BootStrapSymbolDictionaryName put: #UserGlobals. System commitTransaction/).once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(["input #{GemStoneInstallation.current.installation_path}/seaside/topaz/installMonticello.topaz", "commit"]).once.ordered
    partial_mock_stone.should_receive(:topaz_commands).with(/UserGlobals removeKey: #BootStrapSymbolDictionaryName. System commitTransaction/).once.ordered

    stone.initialize_new_stone
  end
end

class GlassStoneIntegrationCase < GlassStoneTestCase
  def test_bootstrap
    stone = GlassStone.create(TEST_STONE_NAME)
    # Will raise an exception if Monticello is not installed
    stone.run_topaz_command("MCPlatformSupport")
  end
end
