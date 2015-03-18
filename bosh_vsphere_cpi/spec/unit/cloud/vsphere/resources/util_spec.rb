require 'spec_helper'

describe VSphereCloud::Resources::Util do
  describe :average_csv do
    it "should compute the average integer value" do
      expect(VSphereCloud::Resources::Util.average_csv("1,2,3")).to eq(2)
    end

    it "should compute the average float value" do
      expect(VSphereCloud::Resources::Util.average_csv("1.5,2.5,3.5")).to eq(2.5)
    end

    it "should return 0 when there is no data" do
      expect(VSphereCloud::Resources::Util.average_csv("")).to eq(0)
    end
  end

  describe :weighted_random do
    it "should calculate the weighted random" do
      util = VSphereCloud::Resources::Util
      expect(util).to receive(:rand).with(3).and_return(0)
      expect(util).to receive(:rand).with(3).and_return(1)
      expect(util).to receive(:rand).with(3).and_return(2)
      expect(util.weighted_random([[:a, 1], [:b, 2]])).to eq(:a)
      expect(util.weighted_random([[:a, 1], [:b, 2]])).to eq(:b)
      expect(util.weighted_random([[:a, 1], [:b, 2]])).to eq(:b)
    end

    it "should return nil when there are no elements" do
      expect(VSphereCloud::Resources::Util.weighted_random([])).to be_nil
    end
  end
end
