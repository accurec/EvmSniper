require 'dotenv'
require_relative './enums'

Dotenv.load

class ConfigManager
  def initialize(network)
    @network = network
  end

  def config
    return @config unless @config.nil?

    @config = if @network == Enums::Network::ETH
      {
        https_uri: ENV['ETH_HTTPS_URI'],
        wss_uri: ENV['ETH_WSS_URI'],
        wallet_key: ENV['WALLET_KEY'],
        uniswap_pair_abi: ENV['UNISWAP_PAIR_ABI_URI'],
        usdc_token_address: ENV['ETH_USDC_ADDRESS'],
        transfer_topic: ENV['ETH_TRANSFER_TOPIC'],
        uniswap_factory_address: ENV['ETH_UNISWAP_FACTORY_ADDRESS'],
        pair_create_topic: ENV['ETH_PAIR_CREATE_TOPIC'],
        weth_address: ENV['ETH_WETH_ADDRESS'],
        token_url_base_address: ENV['ETH_TOKEN_URL_BASE_ADDRESS']
      }
    elsif @network == Enums::Network::POLYGON_POS
      {
        https_uri: ENV['POLYGON_POS_HTTPS_URI'],
        wss_uri: ENV['POLYGON_POS_WSS_URI'],
        wallet_key: ENV['WALLET_KEY'],
        uniswap_pair_abi: ENV['UNISWAP_PAIR_ABI_URI'],
        usdc_token_address: ENV['POLYGON_POS_USDC_ADDRESS'],
        transfer_topic: ENV['POLYGON_POS_TRANSFER_TOPIC'],
        uniswap_factory_address: ENV['POLYGON_POS_UNISWAP_FACTORY_ADDRESS'],
        pair_create_topic: ENV['POLYGON_POS_PAIR_CREATE_TOPIC'],
        weth_address: ENV['POLYGON_POS_WETH_ADDRESS'],
        token_url_base_address: ENV['POLYGON_POS_TOKEN_URL_BASE_ADDRESS']
      }
    elsif @network == Enums::Network::BASE
      {
        https_uri: ENV['BASE_HTTPS_URI'],
        wss_uri: ENV['BASE_WSS_URI'],
        wallet_key: ENV['WALLET_KEY'],
        uniswap_pair_abi: ENV['UNISWAP_PAIR_ABI_URI'],
        usdc_token_address: ENV['BASE_USDC_ADDRESS'],
        transfer_topic: ENV['BASE_TRANSFER_TOPIC'],
        uniswap_factory_address: ENV['BASE_UNISWAP_FACTORY_ADDRESS'],
        pair_create_topic: ENV['BASE_PAIR_CREATE_TOPIC'],
        weth_address: ENV['BASE_WETH_ADDRESS'],
        token_url_base_address: ENV['BASE_TOKEN_URL_BASE_ADDRESS']
      }
    end
  end
end