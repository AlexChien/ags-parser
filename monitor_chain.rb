#!/usr/bin/env ruby
#
# Ruby parser for Angelshares in the Protoshares Blockchain.
# Usage: $ ruby pts_chain.rb [block=35450] [header=1]
#
# Donations accepted:
# - BTC 1Bzc7PatbRzXz6EAmvSuBuoWED96qy3zgc
# - PTS PcDLYukq5RtKyRCeC1Gv5VhAJh88ykzfka
#
# Copyright (C) 2014 donSchoe <donschoe@qhor.net>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.
$:.unshift( File.dirname( __FILE__ ) )

require 'json'
require 'optparse'
require 'yaml'

require 'net/http'
require 'uri'
require 'json'

require 'bitcoin_rpc'

################################################################################
# load from config file to get default value
@config = YAML.load(File.read("config.yml", safe: true))

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} network [options]"

  opts.separator("\nAvailable options:\n")

  opts.on("-c", "--rpcconnect [CONNECTION]",
    "RPC Connection (example: #{@config["bitcoin"]["connection"]})") do |connection|
    options[:connect] = connection
  end

  opts.on("-d", "--debug",
    "Debug Mode (example: #{@config["bitcoin"]["debug"]})") do

    options[:debug] = true
  end

  opts.on("-p", "--clean_csv",
    "Clean CSV (example: #{@config["bitcoin"]["clean_csv"]})") do

    options[:clean_csv] = true
  end

  opts.on("-b", "--block-start [BLOCK HEIGHT]",
    "Starting Block Height to parse (example: #{@config["bitcoin"]["block_start"]})") do |height|

    options[:blockstrt] = height.to_i
  end

  opts.on("--show-header [true|false]",
    "Output header (example: #{@config["bitcoin"]["show_header"]})") do |flag|

    options[:show_header] = flag == 'true'
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts; exit
  end
end.parse!

# check first argument which mandatory
unless ARGV.any? && %w(bitcoin protoshare).include?(ARGV[0].downcase)
  puts "You must provide network (bitcoin|protoshare)"
  puts optparse
  exit
else
  @network = ARGV[0].downcase
  @network_abbr = case @network
  when 'bitcoin'
    'BTC'
  when 'protoshare'
    'PTS'
  end
end

# PTS daemon connection
@connection       = options[:connection] || @config[@network]["connection"]

# Enable/Disable debugging output.
@debug            = options[:debug] || @config[@network]["debug"]

# Enable/Display daily summaries and output clean CSV only.
@clean_csv        = options[:clean_csv] || @config[@network]["clean_csv"]

# If in append mode, show_header will always be false
@show_header      = options[:show_header] || @config[@network]["show_header"]

# gets block number (height) to start the script at
@blockstrt        = options[:blockstrt] || @config[@network]["block_start"]

# network monitor address
@monitor_address  = @config[@network]["monitor_address"]

################################################################################

@rpc = BitcoinRPC.new(@connection)

# initializes global args
@sum = 0.0
@ags = 0
@day = 1388620800
i=0

################################################################################

# script output start (CSV header)
$stdout.sync = true
$stderr.sync = true

@header = "\"BLOCK\";\"DATETIME\";\"TXBITS\";\"SENDER\";\"DONATION[#{@network_abbr}]\";\"DAYSUM[#{@network_abbr}]\";\"DAYRATE[AGS/#{@network_abbr}]\""

puts @header if @show_header

# parses given transactions
def parse_tx(hi=nil, time=nil, tx)

  # gets transaction JSON data
  jsontx = @rpc.getrawtransaction(tx, 1)

  # check every transaction output
  jsontx["vout"].each do |vout|

    # gets recieving address and value
    address = vout["scriptPubKey"]["addresses"]
    value = vout["value"]

    # checks addresses for being angelshares donation address
    if not address.nil?
      if address.include? @monitor_address

        # display daily summary and split CSV data in days
        while (time.to_i > @day.to_i) do

          # disable summary output for clean CSV files
          if not @clean_csv
            puts "+++++ Day Total: #{@sum.round(8)} #{@network_abbr} (#{@ags.round(8)} AGS/#{@network_abbr}) +++++"
            puts ""
            puts "+++++ New Day : #{Time.at(@day.to_i).utc} +++++"
            puts @header
          end

          # reset PTS sum and sitch day
          @sum = 0.0
          @day += 86400
        end

        # gets UTC timestamp
        stamp = Time.at(time.to_i).utc

        # checks each input for sender addresses
        senderhash = Hash.new
        jsontx['vin'].each do |vin|

          # parses the sender from input txid and n
          sendertx = vin['txid']
          sendernn = vin['vout']

          # gets transaction JSON data of the sender
          senderjsontx = @rpc.getrawtransaction(sendertx, 1)

          # scan sender transaction for sender address
          senderjsontx["vout"].each do |sendervout|
            if sendervout['n'].eql? sendernn

              # gets angelshares sender address and input value
              if senderhash[sendervout['scriptPubKey']['addresses'].first.to_s].nil?
                senderhash[sendervout['scriptPubKey']['addresses'].first.to_s] = sendervout['value'].to_f
              else
                senderhash[sendervout['scriptPubKey']['addresses'].first.to_s] += sendervout['value'].to_f
              end
            end
          end
        end

        # gets donation value by each input address of the transaction
        outval = value
        presum = 0.0
        sumval = 0.0
        senderhash.each do |key, inval|
          printval = 0.0
          sumval += inval
          if sumval <= outval
            printval = inval
          else
            printval = outval - presum
          end

          # prints donation stats if input value is above 0
          if printval > 0

            # sums up donated PTS value
            @sum += printval

            # calculates current angelshares ratio
            @ags = 5000.0 / @sum

            txbits = tx
            puts "\"" + hi.to_s + "\";\"" + stamp.to_s + "\";\"" + txbits.to_s + "\";\"" + key.to_s + "\";\"" + printval.round(8).to_s + "\";\"" + @sum.round(8).to_s + "\";\"" + @ags.round(8).to_s + "\""
          end
          presum += inval
        end
      end
    else

      # debugging warning: transaction without output address
      if @debug
        $stderr.puts "!!!WARNG ADDRESS EMPTY #{vout.to_s}"
      end
    end
  end
end

# starts parsing the blockchain in infinite loop
while true do

  # debugging output: loop number & start block height
  if @debug
    $stderr.puts "---DEBUG LOOP #{i}"
    $stderr.puts "---DEBUG BLOCK #{@blockstrt}"
  end

  # gets current block height
  blockhigh = @rpc.getblockcount

  #reads every block by block
  (@blockstrt.to_i..blockhigh.to_i).each do |hi|
    if @debug
      $stderr.puts "---DEBUG BLOCK #{hi}"
    end

    # gets block hash string
    blockhash = @rpc.getblockhash(hi)

    # gets JSON block data
    blockinfo = @rpc.getblock(blockhash)

    # gets block transactions & time
    transactions = blockinfo['tx']
    time = blockinfo['time']

    # parses transactions ...
    if not transactions.nil?
      if not transactions.size <= 1
        transactions.each do |tx|

          # ... one by one
          parse_tx(hi, time, tx)
        end
      else

        # ... only one available
        parse_tx(hi, time, transactions.first)
      end
    else

      # debugging warning: block without transactions
      if @debug
        $stderr.puts "!!!WARNG NO TRANSACTIONS IN BLOCK #{hi}"
      end
    end
  end

  # debugging output: current loop summary
  if @debug
    $stderr.puts "---DEBUG SUM #{@sum.round(8)}"
    $stderr.puts "---DEBUG VALUE #{@ags.round(8)}"
  end

  # resets starting block height to next unparsed block
  @blockstrt = blockhigh.to_i + 1
  i += 1

  # wait for new blocks to appear
  sleep(600)
end
