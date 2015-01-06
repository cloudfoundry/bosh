require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Vm do
  before do
    @reservation = instance_double('Bosh::Director::NetworkReservation')
    @network = instance_double('Bosh::Director::DeploymentPlan::Network')
    allow(@network).to receive(:name).and_return('test_network')
    allow(@network).to receive(:network_settings).with(@reservation).and_return({'ip' => 1})
    @deployment = instance_double('Bosh::Director::DeploymentPlan::Planner')
    @resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
    allow(@resource_pool).to receive(:network).and_return(@network)
    allow(@resource_pool).to receive(:spec).and_return({'size' => 'small'})
    allow(@resource_pool).to receive(:deployment_plan).and_return(@deployment)
    @vm = BD::DeploymentPlan::Vm.new(@resource_pool)
  end

  describe :initialize do
    it 'should create an idle VM for the resource pool' do
      expect(@vm.resource_pool).to eq(@resource_pool)
    end
  end

  describe :network_settings do
    it 'should generate network settings when there is no bound instance' do
      @vm.use_reservation(@reservation)
      expect(@vm.network_settings).to eq({'test_network' => {'ip' => 1}})
    end

    it 'should delegate to the bound instance when present' do
      bound_instance = instance_double('Bosh::Director::DeploymentPlan::Instance')
      allow(bound_instance).to receive(:network_settings).and_return({'dhcp' => 'true'})
      @vm.bound_instance = bound_instance
      expect(@vm.network_settings).to eq({'dhcp' => 'true'})
    end
  end

  describe :networks_changed? do
    before(:each) do
      @vm.use_reservation(@reservation)
    end

    it 'should return true when BOSH Agent provides different settings' do
      @vm.current_state = {'networks' => {'test_network' => {'ip' => 2}}}
      expect(@vm.networks_changed?).to eq(true)
    end

    it 'should return false when BOSH Agent provides same settings' do
      @vm.current_state = {'networks' => {'test_network' => {'ip' => 1}}}
      expect(@vm.networks_changed?).to eq(false)
    end
  end

  describe :resource_pool_changed? do
    it 'should return true when BOSH Agent provides a different spec' do
      allow(@deployment).to receive(:recreate).and_return(false)
      @vm.current_state = {'resource_pool' => {'foo' => 'bar'}}
      expect(@vm.resource_pool_changed?).to eq(true)
    end

    it 'should return false when BOSH Agent provides the same spec' do
      allow(@deployment).to receive(:recreate).and_return(false)
      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      expect(@vm.resource_pool_changed?).to eq(false)
    end

    it 'should return true when the deployment is being recreated' do
      allow(@deployment).to receive(:recreate).and_return(true)
      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      expect(@vm.resource_pool_changed?).to eq(true)
    end

    it 'should return true when VM env changes' do
      allow(@deployment).to receive(:recreate).and_return(false)
      allow(@resource_pool).to receive(:env).and_return({'foo' => 'bar'})

      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      @vm.model = BD::Models::Vm.make

      @vm.model.update(:env => {'foo' => 'bar'})
      expect(@vm.resource_pool_changed?).to eq(false)
      @vm.model.update(:env => {'foo' => 'baz'})
      expect(@vm.resource_pool_changed?).to eq(true)
    end
  end

  describe :changed? do
    before(:each) do
      allow(@vm).to receive(:networks_changed?).and_return(false)
      allow(@vm).to receive(:resource_pool_changed?).and_return(false)
    end

    it 'should return false if nothing changed' do
      expect(@vm.changed?).to eq(false)
    end

    it 'should return true if the network changed' do
      allow(@vm).to receive(:networks_changed?).and_return(true)
      expect(@vm.changed?).to eq(true)
    end

    it 'should return true if the resource pool changed' do
      allow(@vm).to receive(:resource_pool_changed?).and_return(true)
      expect(@vm.changed?).to eq(true)
    end
  end

  describe :clean_vm do
    it 'sets vm to nil' do
      @vm.model = 'fake-vm'
      expect{ @vm.clean_vm }.to change(@vm, :model).to(nil)
    end

    it 'sets current_state to nil' do
      @vm.current_state = 'fake-state'
      expect{ @vm.clean_vm }.to change(@vm, :current_state).to(nil)
    end
  end

  describe '#current_state' do
    context 'when current state is not set' do
      it 'should be nil' do
        expect(@vm.current_state).to be_nil
      end
    end

    context 'when current state is set' do
      context 'but contains the legacy key "release"' do
        it 'should return the current state sans the "release" key so that we transition away from per-job release' do
          @vm.current_state = {
            'networks' => {
              'test_network' => {'ip' => 2}
            },
            'release' => {
              'name' => 'cf', 'version' => '200',
            }
          }
          expect(@vm.current_state).to eq({'networks' => {'test_network' => {'ip' => 2}}})
        end
      end

      context 'and does not contain the legacy key "release"' do
        it 'should return current state' do
          @vm.current_state = {
            'networks' => {
              'test_network' => {'ip' => 2}
            },
          }
          expect(@vm.current_state).to eq({'networks' => {'test_network' => {'ip' => 2}}})
        end
      end
    end
  end
end
