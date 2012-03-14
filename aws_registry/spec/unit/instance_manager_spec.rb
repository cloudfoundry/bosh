# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsRegistry::InstanceManager do

  before(:each) do
    @ec2 = mock("ec2")
    Bosh::AwsRegistry.ec2 = @ec2
  end

  let(:manager) do
    Bosh::AwsRegistry::InstanceManager.new
  end

  def create_instance(params)
    Bosh::AwsRegistry::Models::AwsInstance.create(params)
  end

  def actual_ip_is(ip)
    instances = mock("instances")
    instance = mock("instance")
    @ec2.should_receive(:instances).and_return(instances)
    instances.should_receive(:[]).with("foo").and_return(instance)
    instance.should_receive(:private_ip_address).and_return(ip)
  end

  describe "reading settings" do
    it "returns settings after verifying IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1")
      manager.read_settings("foo", "10.0.0.1").should == "bar"
    end

    it "raises an error if IP cannot be verified" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.2")

      expect {
        manager.read_settings("foo", "10.0.0.1")
      }.to raise_error(Bosh::AwsRegistry::InstanceError,
                       "Instance IP mismatch, expected IP is `10.0.0.1', " \
                       "actual IP is `10.0.0.2'")
    end

    it "doesn't check remote IP if it's not provided" do
      create_instance(:instance_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
    end

    it "raises an error if instance not found" do
      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::AwsRegistry::InstanceNotFound,
                       "Can't find instance `foo'")
    end
  end

  describe "updating settings" do
    it "updates settings (new instance)" do
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end

    it "updates settings (existing instance)" do
      create_instance(:instance_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end
  end

  describe "deleting settings" do
    it "deletes settings" do
      manager.update_settings("foo", "baz")
      manager.delete_settings("foo")

      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::AwsRegistry::InstanceNotFound,
                       "Can't find instance `foo'")
    end

    it "raises an error if instance not found" do
      expect {
        manager.delete_settings("foo")
      }.to raise_error(Bosh::AwsRegistry::InstanceNotFound,
                       "Can't find instance `foo'")
    end
  end

end
