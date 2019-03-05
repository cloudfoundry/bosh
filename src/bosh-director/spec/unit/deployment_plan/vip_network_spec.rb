require 'spec_helper'

describe Bosh::Director::DeploymentPlan::VipNetwork do
  before { @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner') }
  let(:instance_model) { BD::Models::Instance.make }

  describe :initialize do
    it 'defaults cloud properties to empty hash' do
      network = BD::DeploymentPlan::VipNetwork.new({
        'name' => 'foo',
      }, logger)
      expect(network.cloud_properties).to eq({})
    end

    it 'raises an error when cloud properties is NOT a hash' do
      expect do
        BD::DeploymentPlan::VipNetwork.new({
          'name' => 'foo',
          'cloud_properties' => 'not_hash',
        }, logger)
      end.to raise_error(Bosh::Director::ValidationInvalidType)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new({
        'name' => 'foo',
        'cloud_properties' => {
          'foz' => 'baz',
        },
      }, logger)
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
