require 'eth'
require 'logger'
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'byebug' # TODO: remove when done with the code
require 'httparty'
require_relative '../utils/enums'

class EvmSniper
  ETH_SUBSCRIBE_METHOD = 'eth_subscribe'
  LOGS_SUBSCRIBE_PARAM = 'logs'
  JSON_RPC_VERSION = '2.0'
  FROM_BLOCK = '0x0'
  TO_BLOCK = 'latest'

  def initialize(config_manager, test_mode, listener_mode)
    @config_manager = config_manager
    @listener_mode = listener_mode

    setup_logger

    uri = @config_manager.config[:https_uri]
    @logger.info "Initializing EvmSniper with RPC URL: #{uri}..."
    @client = Eth::Client.create(uri)    
    @logger.info "Initializing EvmSniper done!"

    if !test_mode
      @logger.info "Setting up websocket listener..."
      setup_websocket_listener
      @logger.info "Setting up websocket listener done!"
    end
  end

  # ======= Transfers

  def listen_to_transfers(websocket)
    @logger.info "Opening websocket connection..."

    # TODO: Adjust the values here based on chain to which we're connecting to
    # Just generate the message
    subscribe_message = {
      jsonrpc: JSON_RPC_VERSION,
      id: 1,
      method: ETH_SUBSCRIBE_METHOD, # This is an EVM API code
      params: [
        LOGS_SUBSCRIBE_PARAM,
        {
          address: @config_manager.config[:usdc_token_address], # USDC token
          topics: [@config_manager.config[:transfer_topic]], # Transfer topic
          fromBlock: FROM_BLOCK, # This is not strictly necessary, but good to have for learning purposes
          toBlock: TO_BLOCK # This is not strictly necessary, but good to have for learning purposes
        }
      ]
    }
    
    # Send message to subscribe to events
    websocket.send(subscribe_message.to_json)

    @logger.info "Websocket connection has been established!"
  end

  def handle_transfer_message(message)
    data = JSON.parse(message)
    
    case when data['method'] == 'eth_subscription'
      handle_transfer_event(data['params']['result'])
    when data['id'] == 1 && data['result']
      # This is a WSS response message case that we've successfully subscribed with the example subscription ID = 0x5877d60ddc04069bf2cc0604fca9f299
      # {"id"=>1, "result"=>"0x5877d60ddc04069bf2cc0604fca9f299", "jsonrpc"=>"2.0"}
      @logger.info "Successfully subscribed to logs with subscription ID: #{data['result']}."
    when data['error']
      @logger.error "Received error: #{data['error']}"
    end
  rescue JSON::ParserError => e
    @logger.error "Failed to parse message from websocket: #{e.message}"
  end

  def handle_transfer_event(event)
    # Magic numbers here, because the addresses are coming with leasing zeros, and we just want them to be trimmed
    from_address = "0x" + event['topics'][1][-40..-1]
    to_address = "0x" + event['topics'][2][-40..-1]
    amount = event['data'].hex
    
    event_data = {
      tx_hash: event['transactionHash'],
      block_number: event['blockNumber'].hex,
      log_index: event['logIndex'].hex,
      from: from_address,
      to: to_address,
      amount: amount,
      timestamp: Time.now.utc
    }

    @logger.info "Transfer Event Detected!"
    event_data.each do |key, value|
      @logger.info "  #{key.to_s.capitalize}: #{value}"
    end

    # You could add database storage here
    # store_event(event_data)
  end

  # ======= Uniswap create pair

  def listen_to_uniswap_pair_create(websocket)
    @logger.info "Opening websocket connection..."

    # TODO: Adjust the values here based on chain to which we're connecting to
    # Just generate the message
    subscribe_message = {
      jsonrpc: JSON_RPC_VERSION,
      id: 1,
      method: ETH_SUBSCRIBE_METHOD, # This is an EVM API code
      params: [
        LOGS_SUBSCRIBE_PARAM,
        {
          address: @config_manager.config[:uniswap_factory_address], # Uniswap factory V2
          topics: [@config_manager.config[:pair_create_topic]], # PairCreated topic
          fromBlock: FROM_BLOCK, # This is not strictly necessary, but good to have for learning purposes
          toBlock: TO_BLOCK # This is not strictly necessary, but good to have for learning purposes
        }
      ]
    }
    
    # Send message to subscribe to events
    websocket.send(subscribe_message.to_json)

    @logger.info "Websocket connection has been established!"    
  end

  def handle_uniswap_pair_create_message(message)
    data = JSON.parse(message)
    
    case when data['method'] == 'eth_subscription'
      handle_uniswap_pair_create_event(data['params']['result'])
    when data['id'] == 1 && data['result']
      # This is a WSS response message case that we've successfully subscribed with the example subscription ID = 0x5877d60ddc04069bf2cc0604fca9f299
      # {"id"=>1, "result"=>"0x5877d60ddc04069bf2cc0604fca9f299", "jsonrpc"=>"2.0"}
      @logger.info "Successfully subscribed to logs with subscription ID: #{data['result']}."
    when data['error']
      @logger.error "Received error: #{data['error']}"
    end
  rescue JSON::ParserError => e
    @logger.error "Failed to parse message from websocket: #{e.message}"
  end

  def handle_uniswap_pair_create_event(event)
    # Magic numbers here, because the addresses are coming with leasing zeros, and we just want them to be trimmed
    token_1 = "0x" + event['topics'][1][-40..-1]
    token_2 = "0x" + event['topics'][2][-40..-1]
    pair_address = "0x" + event['data'][-104..-65]
    length = event['data'][-64..-1].hex
    token_reserves = get_pair_token_reserves(pair_address)
    tx_hash = event['transactionHash']
    sender = get_sender_from_transaction_hash(tx_hash)
    # pair_address_owner = get_erc20_owner(pair_address)
    # token_1_owner = get_erc20_owner(token_1)
    # token_2_owner = get_erc20_owner(token_2)

    event_data = {
      tx_hash: tx_hash,
      sender: sender,
      block_number: event['blockNumber'].hex,
      log_index: event['logIndex'].hex,
      token_1: token_1,
      # token_1_owner: token_1_owner,
      token_2: token_2,
      # token_2_owner: token_2_owner,
      pair_address: pair_address,
      # pair_address_owner: pair_address_owner,
      length: length,
      pair_total_supply: get_pair_total_supply(pair_address),
      token_1_reserves: token_reserves[0],
      token_2_reserves: token_reserves[1],
      timestamp: Time.now.utc
    }

    @logger.info "Uniswap Pair Create Event Detected!"
    event_data.each do |key, value|
      @logger.info "  #{key.to_s.capitalize}: #{value}"
    end

    if !(token_1.downcase == @config_manager.config[:weth_address].downcase || token_2.downcase == @config_manager.config[:weth_address].downcase)
      @logger.info 'None of tokens is WETH, skipping this pair!'
      return
    end

    handle_new_weth_pair(pair_address, token_1, token_2, token_reserves[0], token_reserves[1])

    # You could add database storage here
    # store_event(event_data)
  end

  # ======= Pair handling

  # TODO: add magic number values to config
  def handle_new_weth_pair(pair_address, token_1, token_2, token_1_reserves, token_2_reserves)
    @logger.info 'Handling new WETH pair...'

    non_weth_token = token_1 == @config_manager.config[:weth_address] ? token_2 : token_1
    weth_token_reserves = token_1 == @config_manager.config[:weth_address] ? token_1_reserves : token_2_reserves
    looks_good = false

    # First, check if the rserves are big enough
    if !token_1_reserves.nil? && 
        !token_2_reserves.nil? && 
        weth_token_reserves >= 2*10**18
      looks_good = true 
    else
      looks_good = false
    end

    # Second, check who is the owner and whether the ownership was revoked


    # Buy token, if checks are good
    
    # Log link to new token that has been bought - DEX screener?
    if looks_good
      link = "#{@config_manager.config[:token_url_base_address]}#{non_weth_token}"

      if weth_token_reserves >= 50*10**18
        File.write('/workspaces/ruby-3/evm_sniper/out/above_50_eth_tokens.txt', "#{link}\n", mode: 'a')
      elsif weth_token_reserves >= 25*10**18
        File.write('/workspaces/ruby-3/evm_sniper/out/above_25_eth_tokens.txt', "#{link}\n", mode: 'a')
      elsif weth_token_reserves >= 10*10**18
        File.write('/workspaces/ruby-3/evm_sniper/out/above_10_eth_tokens.txt', "#{link}\n", mode: 'a')
      elsif weth_token_reserves >= 2*10**18
        File.write('/workspaces/ruby-3/evm_sniper/out/above_2_eth_tokens.txt', "#{link}\n", mode: 'a')
      end

      @logger.info "DEX screener: #{link}" 
    end
    
    @logger.info 'Handling new WETH pair done.'
  end

  # ======= Helpers

  def setup_logger
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    
    # Custom format: [TIME] [SEVERITY] MESSAGE
    @logger.formatter = proc do |severity, datetime, progname, msg|
      timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
      "[#{timestamp}] [#{severity}] #{msg}\n"
    end
    
    @logger.info "Logger initialized for EvmSniper."
  end

  def setup_websocket_listener
      # EM - Event Machine - this is needed for async event processing from websockets
      EM.run do
        websocket = Faye::WebSocket::Client.new(@config_manager.config[:wss_uri])

        # Opening connection to the WSS and sending logs subscribe message to start listening
        websocket.on :open do |event|
          if @listener_mode == Enums::ListenerMode::TRANSFER
            listen_to_transfers(websocket)
          elsif @listener_mode == Enums::ListenerMode::CREATE_PAIR
            listen_to_uniswap_pair_create(websocket)
          end
        end

        # Do something whenever we receive a log message from websocket listener
        websocket.on :message do |event|
          if @listener_mode == Enums::ListenerMode::TRANSFER
            handle_transfer_message(event.data)
          elsif @listener_mode == Enums::ListenerMode::CREATE_PAIR
            handle_uniswap_pair_create_message(event.data)
          end
        end

        # Log that websocket connection has been closed
        websocket.on :close do |event|
          handle_websocket_close
        end
      end
  end

  def handle_websocket_close
    @logger.info "Websocket connection has been closed! Reconnecting..."
    EM.add_timer(3) { setup_websocket_listener }
  end

  def fetch_uniswap_pair_abi
    return @abi unless @abi.nil?

    @logger.info "Fetching Uniswap Pair ABI..."
    @abi = HTTParty.get(@config_manager.config[:uniswap_pair_abi]).parsed_response['abi']
    @logger.info "Fetching Uniswap Pair ABI done!"

    @abi
  rescue => e
    @logger.error "Failed to fetch Uniswap Pair ABI: #{e.message}"
  end

  def check_https_connection_and_config
    @logger.info "Getting current block number..."
    block_number = @client.eth_block_number["result"].to_i(16)
    @logger.info("Current block number is #{block_number}.")
  end

  def get_erc20_owner(erc20_address)
    @logger.info "Checking the owner of #{erc20_address}..."
    erc20_abi = File.read('/workspaces/ruby-3/evm_sniper/abi/erc20_ownable.json')
    erc20_contract = Eth::Contract.from_abi(name: 'ERC20', address: erc20_address, abi: erc20_abi)
    byebug
    erc20_owner = @client.call(erc20_contract, 'owner')
    @logger.info "The owner is #{erc20_owner}."

    erc20_owner
  end

  # TODO: can combine get_pair_total_supply and get_pair_token_reserves
  def get_pair_total_supply(pair_address)
    @logger.info "Getting pair #{pair_address} total supply..."
    contract = Eth::Contract.from_abi(name: 'UniswapV2Pair', address: pair_address, abi: fetch_uniswap_pair_abi)
    total_supply = @client.call(contract, 'totalSupply')
    @logger.info "Pair #{pair_address} total supply is: #{total_supply}."

    total_supply
  rescue => e
    @logger.error "Failed to get pair #{pair_address} total supply. #{e.message}"
  end

  def get_pair_token_reserves(pair_address)
    @logger.info "Getting pair #{pair_address} token reserves..."
    contract = Eth::Contract.from_abi(name: 'UniswapV2Pair', address: pair_address, abi: fetch_uniswap_pair_abi)
    token_0_reserve, token_1_reserve, block_timestamp_last = @client.call(contract, 'getReserves')
    @logger.info "Pair #{pair_address} token reserves is: [#{token_0_reserve}, #{token_1_reserve}]."

    [token_0_reserve, token_1_reserve]
  rescue => e
    @logger.error "Failed to get pair #{pair_address} token reserves. #{e.message}"
  end

  def get_sender_from_transaction_hash(tx_hash)
    @logger.info "Getting sender from transaction #{tx_hash}..."
    sender = @client.eth_get_transaction_by_hash(tx_hash)['result']['from']
    @logger.info "The sender is #{sender}."

    sender
  end
end