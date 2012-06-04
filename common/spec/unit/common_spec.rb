# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

require "common/common"

describe Bosh::Common do
  describe "#which" do
    let(:path) {
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
    }

    it "should return the path when it finds the executable" do
      Bosh::Common.which("foo1", path).should_not be_nil
    end

    it "should return the path when it finds an executable" do
      Bosh::Common.which(%w[foo2 foo1], path).should match(%r{/foo1$})
    end

    it "should return nil when it isn't executable" do
      Bosh::Common.which("foo2", path).should be_nil
    end

    it "should return nil when it doesn't find an executable" do
      Bosh::Common.which("foo1").should be_nil
    end
  end
end
