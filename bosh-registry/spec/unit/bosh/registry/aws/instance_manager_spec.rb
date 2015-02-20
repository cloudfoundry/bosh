require "spec_helper"

describe Bosh::Registry::InstanceManager do
  before(:each) do
    @ec2 = double("ec2")
    allow(AWS::EC2).to receive(:new).and_return(@ec2)
  end

  let(:manager) do
    config = valid_config
    config["cloud"] = {
      "plugin" => "aws",
      "aws" => {
        "access_key_id" => "foo",
        "secret_access_key" => "bar",
        "region" => "foobar",
        "max_retries" => 5
      }
    }
    Bosh::Registry.configure(config)
    Bosh::Registry.instance_manager
  end

  def create_instance(params)
    Bosh::Registry::Models::RegistryInstance.create(params)
  end

  def actual_ip_is(public_ip, private_ip, eip=nil)
    instances = double("instances")
    instance = double("instance")
    if eip
      elastic_ip = double("elastic_ip", :public_ip => eip)
      expect(instance).to receive(:has_elastic_ip?).and_return(true)
      expect(instance).to receive(:elastic_ip).and_return(elastic_ip)
    else
      expect(instance).to receive(:has_elastic_ip?).and_return(false)
    end
    expect(@ec2).to receive(:instances).and_return(instances)
    expect(instances).to receive(:[]).with("foo").and_return(instance)
    expect(instance).to receive(:private_ip_address).and_return(public_ip)
    expect(instance).to receive(:public_ip_address).and_return(private_ip)
  end

  describe "reading settings" do
    it "returns settings after verifying IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1")
      expect(manager.read_settings("foo", "10.0.0.1")).to eq("bar")
    end

    it "returns settings after verifying elastic IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1", "10.0.3.1")
      expect(manager.read_settings("foo", "10.0.3.1")).to eq("bar")
    end

    it "raises an error if IP cannot be verified" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1")

      expect {
        manager.read_settings("foo", "10.0.3.1")
      }.to raise_error(Bosh::Registry::InstanceError,
                       "Instance IP mismatch, expected IP is `10.0.3.1', " \
                       "actual IP(s): `10.0.0.1, 10.0.1.1'")
    end

  end

end
