require "spec_helper"

describe Bosh::WardenCloud::Helpers do
  include Bosh::WardenCloud::Helpers

  context "uuid" do
    it "can generate the correct uuid" do
      uuid("disk").should start_with "disk"
    end
  end
end