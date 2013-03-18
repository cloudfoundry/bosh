# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

require "common/common"

describe Bosh::Common do

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
      Bosh::Common.symbolize_keys(ORIGINAL)
      ORIGINAL.should == duplicate
    end

    it "should return a new hash with all keys as symbols" do
      Bosh::Common.symbolize_keys(ORIGINAL).should == EXPECTED
    end
  end

  describe "::which" do
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

  describe "::retryable" do
    it "should retry the given number of times" do
      Bosh::Common.stub(:sleep)

      count = 0

      Bosh::Common.retryable(tries: 2) do |tries|
        count += 1
        raise StandardError if tries == 0
        true
      end

      count.should == 2
    end

    it "should sleep on each retry the given number of seconds" do
      Bosh::Common.should_receive(:sleep).with(5).twice

      Bosh::Common.retryable(tries: 3, sleep: 5) do |tries|
        raise StandardError if tries < 2
        true
      end
    end

    it "should retry when given error is raised" do
      Bosh::Common.stub(:sleep)

      count = 0

      Bosh::Common.retryable(tries: 3, on: [ArgumentError, RuntimeError]) do |tries|
        count += 1
        raise ArgumentError if tries == 0
        raise RuntimeError if tries == 1
        true
      end

      count.should == 3
    end

    it "should pass error to sleep callback proc" do
      Bosh::Common.stub(:sleep)

      count = 0
      sleep_cb = lambda { |retries, error|
        error.is_a?(ArgumentError).should be_true if retries == 0
        error.is_a?(RuntimeError).should be_true if retries == 1
      }

      Bosh::Common.retryable(tries: 3, on: [ArgumentError, RuntimeError], sleep: sleep_cb) do |tries|
        count += 1
        raise ArgumentError if tries == 0
        raise RuntimeError if tries == 1
        true
      end
    end

    it "should raise an error if that error is raised and isn't in the specified list" do
      expect {
        Bosh::Common.retryable(on: [ArgumentError]) do
          1/0
        end
      }.to raise_error(ZeroDivisionError)
    end

    it "should raise a RetryCountExceeded error if retries exceed" do
      expect {
        Bosh::Common.retryable(tries: 2) do
          false
        end
      }.to raise_error(Bosh::Common::RetryCountExceeded)
    end
  end
end
