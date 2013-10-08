# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "bosh/common/common"

describe Bosh::Common::Common do

  describe "::symbolize_keys" do
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
      Bosh::Common::Common.symbolize_keys(ORIGINAL)
      ORIGINAL.should == duplicate
    end

    it "should return a new hash with all keys as symbols" do
      Bosh::Common::Common.symbolize_keys(ORIGINAL).should == EXPECTED
    end
  end

  describe "::which" do
    let(:path) {
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../../../assets', __FILE__)}"
    }

    it "should return the path when it finds the executable" do
      Bosh::Common::Common.which("foo1", path).should_not be_nil
    end

    it "should return the path when it finds an executable" do
      Bosh::Common::Common.which(%w[foo2 foo1], path).should match(%r{/foo1$})
    end

    it "should return nil when it isn't executable" do
      Bosh::Common::Common.which("foo2", path).should be_nil
    end

    it "should return nil when it doesn't find an executable" do
      Bosh::Common::Common.which("foo1").should be_nil
    end
  end

  describe "::retryable" do
    it 'should create an instance of Bosh::Common::Retryable' do
      opts = {on: StandardError}
      retryer = double(Bosh::Common::Retryable)
      block = Proc.new { true }

      Bosh::Common::Retryable.should_receive(:new).with(opts).and_return retryer
      retryer.should_receive(:retryer)

      Bosh::Common::Common.retryable(opts, &block)
    end
  end

end
