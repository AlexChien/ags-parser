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
$:.unshift( File.expand_path('./lib', File.dirname( __FILE__ )) )
$:.unshift( File.dirname( __FILE__ ) )

require 'json'
require 'optparse'
require 'yaml'

require 'net/http'
require 'uri'
require 'json'

require 'ags'

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
unless ARGV.any? && %w(bitcoin protoshare music).include?(ARGV[0].downcase)
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
  when 'music'
    'MUSIC'
  end
end

# daemon connection
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
@rpc = Ags::BitcoinRPC.new(@connection)

# initializes global args
@sum = 0.0
@ags = 0
# first day speration point
@day = if @network == 'music'
  1412640000 # 2014-10-07 00:00:00 UTC
else
  1388620800 # 2014-01-02 00:00:00 UTC
end
i=0

################################################################################

# script output start (CSV header)
$stdout.sync = true
$stderr.sync = true

@header = "BLOCK;DATETIME;TX;DONAR;DONATION[#{@network_abbr}];DAYSUM[#{@network_abbr}];DAYRATE[AGS/#{@network_abbr}];RELATED_ADDR"

puts @header if @show_header

# starts parsing the blockchain in infinite loop
while true do

  # debugging output: loop number & start block height
  if @debug
    $stderr.puts "---DEBUG LOOP #{i}"
    $stderr.puts "---DEBUG BLOCK #{@blockstrt}"
  end

  # gets current block height
  block_high = @rpc.getblockcount

  #reads every block by block
  (@blockstrt.to_i..block_high.to_i).each do |hi|
    if @debug
      $stderr.puts "---DEBUG BLOCK #{hi}"
    end

    block_info = Ags::Parser.parse_block(@rpc, hi, @monitor_address)

    # display daily summary and split CSV data in days
    while (block_info[:timestamp].to_i > @day.to_i) do

      # disable summary output for clean CSV files
      if not @clean_csv
        @ags = 5000.0 / @sum
        puts "+++++ Day Total: #{@sum.round(8)} #{@network_abbr} (#{@ags.round(8)} AGS/#{@network_abbr}) +++++"
        puts ""
        puts "+++++ New Day : #{Time.at(@day.to_i).utc} +++++"
        puts @header
      end

      # reset PTS sum and sitch day
      @sum = 0.0
      @day += 86400
    end

    # output donation info
    unless block_info[:donation_transactions].empty?
      puts block_info[:donation_transactions].collect{ |d|
        @sum += d[:donation]
        # insert sum and ags rate when donation
        # maintain related address at last position
        # to be compatible with old api
        ( d.values.insert(-2,[@sum.round(8), (5000.0 / @sum).round(8)]) ).join(';')
      }.join("\r\n")
    end
  end

  # resets starting block height to next unparsed block
  @blockstrt = block_high.to_i + 1
  i += 1

  # wait for new blocks to appear
  sleep(600)
end
