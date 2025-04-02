require 'minitest/autorun'
require_relative '../utils/config'
require_relative '../utils/enums'
require_relative '../core/evm_sniper'
require 'byebug'

class EmvSniperTest < Minitest::Test
  def setup
  end

  def test_check_eth_evm_sniper
    @eth_evm_sniper = EvmSniper.new(ConfigManager.new(Enums::Network::ETH), true, Enums::ListenerMode::TRANSFER)
    @eth_evm_sniper.check_https_connection_and_config
  end

  def test_check_polygon_pos_evm_sniper
    @polygon_pos_evm_sniper = EvmSniper.new(ConfigManager.new(Enums::Network::POLYGON_POS), true, Enums::ListenerMode::TRANSFER)
    @polygon_pos_evm_sniper.check_https_connection_and_config
  end

  def test_check_polygon_pos_evm_sniper_pair_total_supply
    @polygon_pos_evm_sniper = EvmSniper.new(ConfigManager.new(Enums::Network::POLYGON_POS), true, Enums::ListenerMode::TRANSFER)
    @polygon_pos_evm_sniper.get_pair_total_supply("0xed81eefff02354f50c5fa7126385cff0d9b18db6")
  end

  def test_check_eth_evm_sniper_pair_token_reserves
    @eth_evm_sniper = EvmSniper.new(ConfigManager.new(Enums::Network::ETH), true, Enums::ListenerMode::TRANSFER)
    @eth_evm_sniper.get_pair_token_reserves("0x324b4689b5f78ee52979dfbf624517e3e2e6104d")
  end

  def test_check_eth_evm_sniper_owner
    @eth_evm_sniper = EvmSniper.new(ConfigManager.new(Enums::Network::ETH), true, Enums::ListenerMode::TRANSFER)
    @eth_evm_sniper.check_erc20_owner('0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48')
  end
end