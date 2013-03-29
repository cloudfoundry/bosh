# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::YamlHelper do
  subject { Bosh::Cli::YamlHelper }

  describe "#check_duplicate_keys" do
    context "when yaml contains anchors" do
      it "does not raise an error" do
        subject.check_duplicate_keys("key1: &key1")
      end
    end

    context "when yaml contains aliases" do
      it "does not raise an error" do
        subject.check_duplicate_keys("key1: *key1")
      end
    end
  end
end
