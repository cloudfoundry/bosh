require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ManualNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  describe :initialize do
    it 'should parse subnets' do
      received_network = nil
      allow(BD::DeploymentPlan::NetworkSubnet).to receive(:new) do |network, spec|
        received_network = network
        expect(spec).to eq({'foz' => 'baz'})
      end

      network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
            {
                'foz' => 'baz'
            }
          ]
      })
      expect(received_network).to eq(network)
    end

    it 'should not allow overlapping subnets' do
      subnet_a = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      subnet_b = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      allow(BD::DeploymentPlan::NetworkSubnet).to receive(:new).
          and_return(subnet_a, subnet_b)

      expect(subnet_a).to receive(:overlaps?).with(subnet_b).and_return(true)

      expect {
        BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
            'name' => 'foo',
            'subnets' => [
                {
                    'foz' => 'baz'
                },
                {
                    'foz2' => 'baz2'
                }
            ]
        })
      }.to raise_error(Bosh::Director::NetworkOverlappingSubnets)
    end
  end

  describe :reserve do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      allow(@subnet).to receive(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      allow(BD::DeploymentPlan::NetworkSubnet).to receive(:new).and_return(@subnet)

      @network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
              {
                  'foz' => 'baz',
                  'gateway' => '192.168.0.254',
              }
          ]
      })
    end

    it 'should reserve an existing IP' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      expect(@subnet).to receive(:reserve_ip).with(1).and_return(:dynamic)
      @network.reserve(reservation)

      expect(reservation.reserved).to eq(true)
    end

    it 'should allocated dynamic IP' do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      expect(@subnet).to receive(:allocate_dynamic_ip).and_return(2)
      @network.reserve(reservation)

      expect(reservation.reserved).to eq(true)
      expect(reservation.ip).to eq(2)
    end

    it 'should not let you reserve a used IP' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      expect(@subnet).to receive(:reserve_ip).with(1).and_return(nil)
      @network.reserve(reservation)

      expect(reservation.reserved).to eq(false)
      expect(reservation.error).to eq(BD::NetworkReservation::USED)
    end

    it 'should not let you reserve an IP in the wrong pool' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      expect(@subnet).to receive(:reserve_ip).with(1).and_return(:static)
      @network.reserve(reservation)

      expect(reservation.reserved).to eq(false)
      expect(reservation.error).to eq(BD::NetworkReservation::WRONG_TYPE)
    end

    it "should raise an error when it's out of capacity" do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      expect(@subnet).to receive(:allocate_dynamic_ip).and_return(nil)
      @network.reserve(reservation)

      expect(reservation.reserved).to eq(false)
      expect(reservation.error).to eq(BD::NetworkReservation::CAPACITY)
    end
  end

  describe :release do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      allow(@subnet).to receive(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      allow(BD::DeploymentPlan::NetworkSubnet).to receive(:new).and_return(@subnet)

      @network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
              {
                  'foz' => 'baz'
              }
          ]
      })
    end

    it 'should release the IP from the subnet' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      expect(@subnet).to receive(:release_ip).with(1)
      @network.release(reservation)
    end

    it 'should fail when there is no IP' do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      expect {
        @network.release(reservation)
      }.to raise_error(/without an IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      allow(@subnet).to receive(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      allow(@subnet).to receive(:netmask).and_return('255.255.255.0')
      allow(@subnet).to receive(:cloud_properties).and_return({'VLAN' => 'a'})
      allow(@subnet).to receive(:dns).and_return(nil)
      allow(@subnet).to receive(:gateway).and_return(nil)
      allow(BD::DeploymentPlan::NetworkSubnet).to receive(:new).and_return(@subnet)

      @network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
              {
                  'foz' => 'baz'
              }
          ]
      })
    end

    it 'should provide the network settings from the subnet' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      expect(@network.network_settings(reservation, [])).to eq({
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'default' => []
      })
    end

    it 'should set the defaults' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      expect(@network.network_settings(reservation)).to eq({
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'default' => ['dns', 'gateway']
      })
    end

    it 'should provide the DNS if available' do
      allow(@subnet).to receive(:dns).and_return(['1.2.3.4', '5.6.7.8'])
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      expect(@network.network_settings(reservation, [])).to eq({
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'dns' => ['1.2.3.4', '5.6.7.8'],
          'default' => []
      })
    end

    it 'should provide the gateway if available' do
      allow(@subnet).to receive(:gateway).and_return(NetAddr::CIDR.create('0.0.0.254'))
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      expect(@network.network_settings(reservation, [])).to eq({
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'gateway' => '0.0.0.254',
          'default' => []
      })
    end

    it 'should fail when there is no IP' do
      allow(@subnet).to receive(:dns).and_return(['1.2.3.4', '5.6.7.8'])
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      expect {
        @network.network_settings(reservation)
      }.to raise_error(/without an IP/)
    end
  end
end
