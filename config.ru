require './core/evm_sniper'
require './utils/config'
require './utils/enums'

evm_sniper = EvmSniper.new(
  ConfigManager.new(Enums::Network::ETH), 
  false, 
  Enums::ListenerMode::CREATE_PAIR
)

run evm_sniper