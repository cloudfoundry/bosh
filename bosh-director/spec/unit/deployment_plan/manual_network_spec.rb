# Copyright (c) 2009-2012 VMware, Inc.
require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ManualNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  describe :initialize do
    it 'should parse subnets' do
      received_network = nil
      BD::DeploymentPlan::NetworkSubnet.stub(:new) do |network, spec|
        received_network = network
        spec.should == {'foz' => 'baz'}
      end

      network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
            {
                'foz' => 'baz'
            }
          ]
      })
      received_network.should == network
    end

    it 'should not allow overlapping subnets' do
      subnet_a = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      subnet_b = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      BD::DeploymentPlan::NetworkSubnet.stub(:new).
          and_return(subnet_a, subnet_b)

      subnet_a.should_receive(:overlaps?).with(subnet_b).and_return(true)

      lambda {
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
      }.should raise_error(Bosh::Director::NetworkOverlappingSubnets)
    end
  end

  describe :reserve do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      @subnet.stub(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      BD::DeploymentPlan::NetworkSubnet.stub(:new).and_return(@subnet)

      @network = BD::DeploymentPlan::ManualNetwork.new(@deployment_plan, {
          'name' => 'foo',
          'subnets' => [
              {
                  'foz' => 'baz'
              }
          ]
      })
    end

    it 'should reserve an existing IP' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      @subnet.should_receive(:reserve_ip).with(1).and_return(:dynamic)
      @network.reserve(reservation)

      reservation.reserved.should == true
    end

    it 'should allocated dynamic IP' do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      @subnet.should_receive(:allocate_dynamic_ip).and_return(2)
      @network.reserve(reservation)

      reservation.reserved.should == true
      reservation.ip.should == 2
    end

    it 'should not let you reserve a used IP' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      @subnet.should_receive(:reserve_ip).with(1).and_return(nil)
      @network.reserve(reservation)

      reservation.reserved.should == false
      reservation.error.should == BD::NetworkReservation::USED
    end

    it 'should not let you reserve an IP in the wrong pool' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)
      reservation.reserved = true

      @subnet.should_receive(:reserve_ip).with(1).and_return(:static)
      @network.reserve(reservation)

      reservation.reserved.should == false
      reservation.error.should == BD::NetworkReservation::WRONG_TYPE
    end

    it "should raise an error when it's out of capacity" do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      @subnet.should_receive(:allocate_dynamic_ip).and_return(nil)
      @network.reserve(reservation)

      reservation.reserved.should == false
      reservation.error.should == BD::NetworkReservation::CAPACITY
    end
  end

  describe :release do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      @subnet.stub(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      BD::DeploymentPlan::NetworkSubnet.stub(:new).and_return(@subnet)

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

      @subnet.should_receive(:release_ip).with(1)
      @network.release(reservation)
    end

    it 'should fail when there is no IP' do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      lambda {
        @network.release(reservation)
      }.should raise_error(/without an IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @subnet = instance_double('Bosh::Director::DeploymentPlan::NetworkSubnet')
      @subnet.stub(:range).and_return(NetAddr::CIDR.create('0.0.0.1/24'))
      @subnet.stub(:netmask).and_return('255.255.255.0')
      @subnet.stub(:cloud_properties).and_return({'VLAN' => 'a'})
      @subnet.stub(:dns).and_return(nil)
      @subnet.stub(:gateway).and_return(nil)
      BD::DeploymentPlan::NetworkSubnet.stub(:new).and_return(@subnet)

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

      @network.network_settings(reservation, []).should == {
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'default' => []
      }
    end

    it 'should set the defaults' do
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      @network.network_settings(reservation).should == {
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'default' => ['dns', 'gateway']
      }
    end

    it 'should provide the DNS if available' do
      @subnet.stub(:dns).and_return(['1.2.3.4', '5.6.7.8'])
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      @network.network_settings(reservation, []).should == {
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'dns' => ['1.2.3.4', '5.6.7.8'],
          'default' => []
      }
    end

    it 'should provide the gateway if available' do
      @subnet.stub(:gateway).and_return(NetAddr::CIDR.create('0.0.0.254'))
      reservation = BD::NetworkReservation.new(
          :ip => '0.0.0.1', :type => BD::NetworkReservation::DYNAMIC)

      @network.network_settings(reservation, []).should == {
          'ip' => '0.0.0.1',
          'netmask' => '255.255.255.0',
          'cloud_properties' => {'VLAN' => 'a'},
          'gateway' => '0.0.0.254',
          'default' => []
      }
    end

    it 'should fail when there is no IP' do
      @subnet.stub(:dns).and_return(['1.2.3.4', '5.6.7.8'])
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      lambda {
        @network.network_settings(reservation)
      }.should raise_error(/without an IP/)
    end
  end
end
