#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), '..', 'glass_stone')
require 'common_test_case'

class Date
  def to_Ymd_string
    strftime("%Y-%m-%d")
  end
end

class GlassStoneTestCase < BaseTestCase
  def test_find_port_numbers_from_lighty
    stone, mock_stone = mock_stone_lighty_config(TEST_STONE_NAME)
    assert_equal(['8000', '1234'],stone.hyper_ports_lighty)
    stone, mock_stone= mock_stone_lighty_config("agdev.lan")
    assert_equal(['9000', '9001'],stone.hyper_ports_lighty)
  end

  def test_hyper_service_needs_lang_environment_variable
    ENV['LANG'] = nil
    assert_raises(RuntimeError) { GlassStone.new(nil).start_hyper_fg(1234) }
  end

  def test_services_names
    stone, mock_stone = mock_stone_lighty_config(TEST_STONE_NAME)
    assert_equal(["#{TEST_STONE_NAME}-8000", "#{TEST_STONE_NAME}-1234"], stone.services_names)
  end

  def test_hypers_start
    stone, mock_stone = mock_stone_lighty_config(TEST_STONE_NAME)
    mock_stone.should_receive(:sh).with("svc -u /service/#{TEST_STONE_NAME}-8000").once
    mock_stone.should_receive(:sh).with("svc -u /service/#{TEST_STONE_NAME}-1234").once
    stone.start_hypers
  end

  def test_hypers_start_for_second_stone
    stone, mock_stone = mock_stone_lighty_config('stone2.finworks.biz')
    mock_stone.should_receive(:sh).with("svc -u /service/stone2.finworks.biz-5000").once
    mock_stone.should_receive(:sh).with("svc -u /service/stone2.finworks.biz-9876").once
    stone.start_hypers
  end

  def mock_stone_lighty_config(stone_name)
    stone = GlassStone.new(stone_name)
    partial_mock_stone = flexmock(stone)
    partial_mock_stone.should_receive(:lighty_config).and_return(mock_lighty_config)
    return stone, partial_mock_stone
  end

  def mock_lighty_config
    <<-MOCK
    $SERVER["socket"] == "0.0.0.0:443" {
                      ssl.engine                  = "enable"
                      ssl.pemfile                 = "/etc/lighttpd/server.pem"

      $HTTP["host"] == "#{TEST_STONE_NAME}" {
          proxy.server  = ( "" => (( "host" => "127.0.0.1", "port" => 8000 ),
                                   ( "host" => "127.0.0.1", "port" => 1234 ), ))
      }
      $HTTP["host"] =~ "agdev.lan" {
          proxy.server  = ( "" => (( "host" => "127.0.0.1", "port" => 9000 ),
                                   ( "host" => "127.0.0.1", "port" => 9001 ), ))
      }
    }

    $SERVER["socket"] == "1.2.3.4:443" {
                      ssl.engine                  = "enable"
                      ssl.pemfile                 = "/etc/lighttpd/server.pem"

      $HTTP["host"] == "stone2.finworks.biz" {
          proxy.server  = ( "" => (( "host" => "127.0.0.1", "port" => 5000 ),
                                   ( "host" => "127.0.0.1", "port" => 9876 ), ))
      }
    }
    MOCK
  end
end

class GlassStoneIntegrationTestCase < BaseTestCase

  def setup
    super
    @stone = GlassStone.create(TEST_STONE_NAME)
  end

  def test_hypers_status
    @stone.create_lighty_config([9999])
    @stone.create_daemontools_structure
    deny(@stone.any_hyper_supposed_to_be_running?) 
    deny(@stone.any_hyper_running?) 
    @stone.start
    deny(@stone.any_hyper_supposed_to_be_running?) 
    deny(@stone.any_hyper_running?) 
    supervise_ok = "/service/#{@stone.services_names.first}/supervise/ok"
    while (not File.exists? supervise_ok) do
      sleep 1
      puts "Waiting for #{supervise_ok}"
    end
    @stone.start_hypers
    sleep 3
    assert(@stone.any_hyper_supposed_to_be_running?) 
    # assert(@stone.any_hyper_running?) . This code assumes that the
    # created database is bootstrapped with GLASS and that the hyper code
    # will work in the script glass_hyper. In our environment, we have the
    # option to start with a bootstrapped extent, which we pre-build. Not
    # sure how to fold this into GlassStone now. Perhaps a GlassStone
    # should also be bootstrapped. We must just then migrate the code that
    # builds the bootstrapped extent into gemstone-scritps as well. TODO
    # then.
    @stone.stop_hypers
    @stone.remove_daemontools_structure
    @stone.remove_lighty_config
  end
end
