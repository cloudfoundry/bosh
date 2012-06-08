# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

require "common/common"

describe Bosh::Common do

  describe "#symbolize_keys" do
    ORIGINAL = {
      "foo1" => "bar",
      :foo2 => "bar",
      "foo3" => {
        "foo4" => "bar"
      }
    }.freeze

    EXPECTED = {
      :foo1 => "bar",
      :foo2 => "bar",
      :foo3 => {
        :foo4 => "bar"
      }
    }.freeze

    it "should not modify the original hash" do
      duplicate = ORIGINAL.dup
      Bosh::Common.symbolize_keys(ORIGINAL)
      ORIGINAL.should == duplicate
    end

    it "should return a new hash with all keys as symbols" do
      Bosh::Common.symbolize_keys(ORIGINAL).should == EXPECTED
    end
  end

end
