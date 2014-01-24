require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::DeploymentPlan::IdleVm do
  before(:each) do
    @reservation = instance_double('Bosh::Director::NetworkReservation')
    @network = instance_double('Bosh::Director::DeploymentPlan::Network')
    @network.stub(:name).and_return('test_network')
    @network.stub(:network_settings).with(@reservation).and_return({'ip' => 1})
    @deployment = instance_double('Bosh::Director::DeploymentPlan::Planner')
    @resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
    @resource_pool.stub(:network).and_return(@network)
    @resource_pool.stub(:spec).and_return({'size' => 'small'})
    @resource_pool.stub(:deployment_plan).and_return(@deployment)
    @vm = BD::DeploymentPlan::IdleVm.new(@resource_pool)
  end

  describe :initialize do
    it 'should create an idle VM for the resource pool' do
      @vm.resource_pool.should == @resource_pool
    end
  end

  describe :network_settings do
    it 'should generate network settings when there is no bound instance' do
      @vm.use_reservation(@reservation)
      @vm.network_settings.should == {'test_network' => {'ip' => 1}}
    end

    it 'should delegate to the bound instance when present' do
      bound_instance = instance_double('Bosh::Director::DeploymentPlan::Instance')
      bound_instance.stub(:network_settings).and_return({'dhcp' => 'true'})
      @vm.bound_instance = bound_instance
      @vm.network_settings.should == {'dhcp' => 'true'}
    end
  end

  describe :networks_changed? do
    before(:each) do
      @vm.use_reservation(@reservation)
    end

    it 'should return true when BOSH Agent provides different settings' do
      @vm.current_state = {'networks' => {'test_network' => {'ip' => 2}}}
      @vm.networks_changed?.should == true
    end

    it 'should return false when BOSH Agent provides same settings' do
      @vm.current_state = {'networks' => {'test_network' => {'ip' => 1}}}
      @vm.networks_changed?.should == false
    end
  end

  describe :resource_pool_changed? do
    it 'should return true when BOSH Agent provides a different spec' do
      @deployment.stub(:recreate).and_return(false)
      @vm.current_state = {'resource_pool' => {'foo' => 'bar'}}
      @vm.resource_pool_changed?.should == true
    end

    it 'should return false when BOSH Agent provides the same spec' do
      @deployment.stub(:recreate).and_return(false)
      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      @vm.resource_pool_changed?.should == false
    end

    it 'should return true when the deployment is being recreated' do
      @deployment.stub(:recreate).and_return(true)
      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      @vm.resource_pool_changed?.should == true
    end

    it 'should return true when VM env changes' do
      @deployment.stub(:recreate).and_return(false)
      @resource_pool.stub(:env).and_return({'foo' => 'bar'})

      @vm.current_state = {'resource_pool' => {'size' => 'small'}}
      @vm.vm = BD::Models::Vm.make

      @vm.vm.update(:env => {'foo' => 'bar'})
      @vm.resource_pool_changed?.should == false
      @vm.vm.update(:env => {'foo' => 'baz'})
      @vm.resource_pool_changed?.should == true
    end
  end

  describe :changed? do
    before(:each) do
      @vm.stub(:networks_changed?).and_return(false)
      @vm.stub(:resource_pool_changed?).and_return(false)
    end

    it 'should return false if nothing changed' do
      @vm.changed?.should == false
    end

    it 'should return true if the network changed' do
      @vm.stub(:networks_changed?).and_return(true)
      @vm.changed?.should == true
    end

    it 'should return true if the resource pool changed' do
      @vm.stub(:resource_pool_changed?).and_return(true)
      @vm.changed?.should == true
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
