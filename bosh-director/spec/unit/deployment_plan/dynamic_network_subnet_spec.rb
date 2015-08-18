require 'spec_helper'

describe 'Bosh::Director::DeploymentPlan::DynamicNetworkSubnet' do
  def make_subnet(availability_zone)
    availability_zone_name = BD::DeploymentPlan::AvailabilityZoneName.new(availability_zone, 'network-name')
    BD::DeploymentPlan::DynamicNetworkSubnet.new('4.4.4.4', {'foo' => 'bar'}, availability_zone_name)
  end

  describe 'validate!' do
    context 'with no availability zone specified' do
      it 'does not care whether that az name is in the list' do
        subnet = make_subnet(nil)

        expect { subnet.validate!([]) }.to_not raise_error
      end
    end

    context 'with an availability zone that is present' do
      it 'is valid' do
        subnet = make_subnet('foo')

        expect {
          subnet.validate!([
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'bar'),
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'foo'),
            ])
        }.to_not raise_error
      end
    end

    context 'with an availability zone that is not present' do
      it 'errors' do
        subnet = make_subnet('foo')

        expect {
          subnet.validate!([
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'bar'),
            ])
        }.to raise_error(Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network 'network-name' refers to an unknown availability zone 'foo'")
      end
    end
  end
end
