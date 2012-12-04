require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Helpers do

  include Bosh::WardenCloud::Helpers

  context "uuid" do
    it "can generate the correct uuid" do
      uuid('disk').should start_with 'disk'
    end
  end
end
