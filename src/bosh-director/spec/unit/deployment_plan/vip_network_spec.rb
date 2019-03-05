require 'spec_helper'

describe Bosh::Director::DeploymentPlan::VipNetwork do
  include Bosh::Director::IpUtil

  before { @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner') }
  let(:instance_model) { BD::Models::Instance.make }
  let(:network_spec) do
    {
      'name' => 'foo',
      'subnets' => [
        { 'static_ips' => ['69.69.69.69'] },
        { 'static_ips' => ['70.70.70.70', '80.80.80.80'] },
      ],
    }
  end

  let(:azs) do
    [
      Bosh::Director::DeploymentPlan::AvailabilityZone.new('z1', {}),
      Bosh::Director::DeploymentPlan::AvailabilityZone.new('z2', {}),
    ]
  end

  describe :parse do
    it 'defaults cloud properties to empty hash' do
      network = BD::DeploymentPlan::VipNetwork.parse(network_spec, azs, logger)
      expect(network.cloud_properties).to eq({})
    end

    it 'correctly parses the subnets defined in the network spec' do
      vip_network = BD::DeploymentPlan::VipNetwork.parse(network_spec, azs, logger)
      expect(vip_network).to be_a(BD::DeploymentPlan::VipNetwork)
      expect(vip_network.subnets.size).to eq(2)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.parse({
        'name' => 'foo',
        'cloud_properties' => {
          'foz' => 'baz',
        },
      }, azs, logger)
    end

    it 'should provide the VIP network settings' do
      reservation = BD::DesiredNetworkReservation.new_static(instance_model, @network, '0.0.0.1')

      expect(@network.network_settings(reservation, [])).to eq(
        'type' => 'vip',
        'ip' => '0.0.0.1',
        'cloud_properties' => {
          'foz' => 'baz',
        },
      )
    end

    it 'should fail if there are any defaults' do
      reservation = BD::DesiredNetworkReservation.new_static(instance_model, @network, '0.0.0.1')

      expect do
        @network.network_settings(reservation)
      end.to raise_error(/Can't provide any defaults/)

      expect do
        @network.network_settings(reservation, nil)
      end.not_to raise_error
    end
  end
end
