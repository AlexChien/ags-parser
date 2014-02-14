module Ags
  class Parser
    # Parse block
    #
    # @param rpc [BitcoinRPC]: BitcoinRPC instance
    # @param block_height [Integer]: Block height
    #
    # @return [Hash]: { block_height: Integer, timestamp: Integer, donation_transactions: [{:txid, :donar_address, :donation, :inputs},..] }
    def self.parse_block(rpc, block_height, qualify_output)
      donation_transactions = []

      # gets block hash string
      blockhash = rpc.getblockhash(block_height)

      # gets JSON block data
      blockinfo = rpc.getblock(blockhash)

      # gets block transactions & time
      transactions = blockinfo['tx']
      time = blockinfo['time']

      # parses transactions ...
      transactions.to_a.each do |tx|
        # ... one by one
        donation = Ags::Parser.parse_tx(rpc, block_height, tx, qualify_output)
        donation_transactions << donation unless donation.nil?
      end unless transactions.nil?

      return { block_height: block_height, timestamp: time, donation_transactions: donation_transactions }
    end

    # Parse transaction to extract AGS donation infomation
    #
    # @param rpc [BitcoinRPC]: BitcoinRPC instance
    # @param block_height [Integer]: Block height
    # @param tx_id [String]: transaction id
    # @param qualify_address [String]: AGS target donation address (BTC or PTS)
    #
    # @return Hash {:txid, :donar_address, :donation, :inputs}
    #
    def self.parse_tx(rpc, block_height, tx_id, qualify_output)
      # gets transaction JSON data
      jsontx = rpc.getrawtransaction(tx_id, 1)

      found = false
      result = {
        block: block_height, datetime: nil, txid: tx_id, donar_address: nil, donation: 0.0, inputs:[]
      }

      # check every transaction output
      jsontx["vout"].each do |vout|

        # gets recieving address and value
        address = vout["scriptPubKey"]["addresses"]
        value = vout["value"]

        # checks addresses for being angelshares donation address
        if not address.nil?
          if address.include? qualify_output
            found = true

            # gets donation value by each input address of the transaction
            result[:donation] += value
          end
        else
          # debugging warning: transaction without output address
          if @debug
            $stderr.puts "!!!WARNG ADDRESS EMPTY #{vout.to_s}"
          end
        end

      end

      if found
        result[:donar_address] = get_output(rpc, jsontx['vin'].first)
        result[:datetime] = Time.at(jsontx["blocktime"].to_i).utc
        result[:inputs] = jsontx["vin"].collect{ |vin| get_output(rpc, vin) }.uniq.drop(1).join(',')
      end

      return found ? result : nil
    end

    # parses the output address from input txid and n
    #
    # @param rpc [BitcoinRPC]: BitcoinRPC instance
    # @param vin [Hash]: input[x]
    #
    # @return [String]: output address
    def self.get_output(rpc, vin)
      sendertx = vin['txid']
      sendernn = vin['vout']

      # gets transaction JSON data of the sender
      outputjsontx = rpc.getrawtransaction(sendertx, 1)

      # scan sender transaction for sender address
      outputjsontx["vout"].each do |sendervout|
        if sendervout['n'].eql? sendernn
          return sendervout['scriptPubKey']['addresses'].first.to_s
        end
      end
    end
  end
end
