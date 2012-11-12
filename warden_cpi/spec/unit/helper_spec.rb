require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Helpers do

  include Bosh::WardenCloud::Helpers

  context "uuid" do
    it "can generate the correct uuid" do
      disk_uuid.should start_with 'disk'
    end

    it "throw exceptions on missed methods other than uuid" do
      expect {
        unknown_method()
      }.to raise_error NoMethodError
    end
  end
end
