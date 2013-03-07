require 'spec_helper'
require 'bosh_agent/platform'

describe Bosh::Agent::Platform do

  context "Ubuntu" do
    it "loads the correct platform" do
      Bosh::Agent::Platform.new("ubuntu")
      require('bosh_agent/platform/ubuntu').should be_false
    end
    it "returns the correct class" do
      Bosh::Agent::Platform.new("ubuntu").platform.should be_a_kind_of Bosh::Agent::Platform::Ubuntu
    end
  end

  context "Rhel" do
    it "loads the correct platform" do
      Bosh::Agent::Platform.new("rhel")
      require('bosh_agent/platform/rhel').should be_false
    end
    it "returns the correct class" do
      Bosh::Agent::Platform.new("rhel").platform.should be_a_kind_of Bosh::Agent::Platform::Rhel
    end
  end

  it "raises exception in case platform is not found" do
    lambda {Bosh::Agent::Platform.new("unknown")}.should raise_exception(Bosh::Agent::UnknownPlatform)
  end

end