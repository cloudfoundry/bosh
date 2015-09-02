require 'spec_helper'

describe Bosh::AwsCloud::Cloud, "delete_vm" do
  let(:cloud) { described_class.new(options) }

  let(:options) do
    {
      "aws" => {
        "default_availability_zone" => "foo",
        "region" => "bar",
        "access_key_id" => "access",
        "secret_access_key" => "secret",
        "default_key_name" => "sesame"
      },
      "registry" => {
        "endpoint" => "endpoint",
        "user" => "user",
        "password" => "password"
      },
      "agent" => {
        "baz" => "qux"
      }
    }
  end

  it 'deletes an EC2 instance' do
    registry = double("registry")
    allow(Bosh::Registry::Client).to receive(:new).and_return(registry)

    region = double("region", name: 'bar')
    allow(AWS::EC2).to receive(:new).and_return(double("ec2", regions: [ region ]))

    az_selector = double("availability zone selector")
    allow(Bosh::AwsCloud::AvailabilityZoneSelector).to receive(:new).
      with(region, "foo").
      and_return(az_selector)

    instance_manager = instance_double('Bosh::AwsCloud::InstanceManager')
    allow(Bosh::AwsCloud::InstanceManager).to receive(:new).
      with(region, registry, be_an_instance_of(AWS::ELB), az_selector, be_an_instance_of(Logger)).
      and_return(instance_manager)

    instance = instance_double('Bosh::AwsCloud::Instance')
    allow(instance_manager).to receive(:find).with('fake-id').and_return(instance)

    expect(instance).to receive(:terminate).with(false)

    cloud.delete_vm('fake-id')
  end
end
