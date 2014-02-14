require 'spec_helper'

describe Ags::Parser do
  let(:btc_angel_address) { "1ANGELwQwWxMmbdaSWhWLqBEtPTkWb8uDc" }
  let(:pts_angel_address) { "PaNGELmZgzRQCKeEKM6ifgTqNkC4ceiAWw" }
  before(:each) do
    @rpc = double()
    @rpc.stub(:getrawtransaction) do |tx_id, verbose|
      JSON.parse(File.open("spec/ags/fixtures/#{tx_id}.json", 'rb') { |f| f.read }) if verbose == 1
    end
  end

  context "non donation transaction" do
    it "should raise exception" do
      tx = 'abefc79ee31a9264496823e12feb477543efa731e074e28414ce92d207c1b430'

      result = Ags::Parser.parse_tx(@rpc, 285657, tx, btc_angel_address)
      result.should be_nil
    end
  end

  context "single input" do
    before do
      tx = 'dbc8afb1b23eed6b777aa08f35e593e199b52d9fd8eeaa1ca19d661d8649b1ca'

      @result = Ags::Parser.parse_tx(@rpc, 281582, tx, btc_angel_address)
    end

    it "should return hash" do
      @result[:block].should == 281582
      @result[:datetime].to_s.should == '2014-01-20 23:17:10 UTC'
      @result[:txid].should == 'dbc8afb1b23eed6b777aa08f35e593e199b52d9fd8eeaa1ca19d661d8649b1ca'
      @result[:donar_address].should == '1HddTkBSaxVnRL2XPpgFMVChj8BSWWC5mN'
      @result[:donation].should == 0.1
      @result[:inputs].should == ""
    end
  end

  context "mutiple inputs" do
    before do
      tx = 'a47f12254a196bf7255ff76d83fb8767a8abf2a15bed10172c59316c0d1cea8d'

      @result = Ags::Parser.parse_tx(@rpc, 51265, tx, pts_angel_address)
    end

    it "should return hash" do
      @result[:block].should == 51265
      @result[:datetime].to_s.should == '2014-02-14 04:32:23 UTC'
      @result[:txid].should == 'a47f12254a196bf7255ff76d83fb8767a8abf2a15bed10172c59316c0d1cea8d'
      @result[:donar_address].should == 'Pn3NFVrz2tP4gNqxwQM6Wjyx4g8C3Sgw6q'
      @result[:donation].should == 2.0
      @result[:inputs].should == 'PbNWVqcQZrbrSWEi5aVwFpWF2CJkmQgVLX,PbtCiL6BLDiuV7jSYzZEV7a8gsNthw5hJn'
    end
  end

  context "duplicated inputs" do
    before do
      tx = 'd2b64a6d2e3860bfc6f37774bad6e7c4bfbc1ea63716de4bc146188f8e63e61e'

      @result = Ags::Parser.parse_tx(@rpc, 277644, tx, btc_angel_address)
    end

    it "should return hash" do
      @result[:block].should == 277644
      @result[:datetime].to_s.should == '2013-12-30 01:01:12 UTC'
      @result[:txid].should == 'd2b64a6d2e3860bfc6f37774bad6e7c4bfbc1ea63716de4bc146188f8e63e61e'
      @result[:donar_address].should == '1KHXpgQLeLgMTZmP5JVss5XX55UUTFunPP'
      @result[:donation].should == 0.30437446
      @result[:inputs].should == '1Q4isu8WRDn8Withk4GhM4vbeKNdRcq7TH'
    end
  end
end