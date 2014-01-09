require 'spec_helper'

describe Bosh::Director::VmCreator do

  before do
    @cloud = instance_double('Bosh::Cloud')
    Bosh::Director::Config.stub(:cloud).and_return(@cloud)
    Bosh::Director::Config.max_vm_create_tries = 2

    @deployment = Bosh::Director::Models::Deployment.make

    @deployment_plan = double('deployment_plan')
    @deployment_plan.stub(:deployment).and_return(@deployment)
    @deployment_plan.stub(:name).and_return('deployment_name')

    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => 'stemcell-id')

    @stemcell_spec = double('stemcell_spec')
    @stemcell_spec.stub(:stemcell).and_return(@stemcell)

    @resource_pool_spec = double('resource_pool_spec')
    @resource_pool_spec.stub(:deployment).and_return(@deployment_plan)
    @resource_pool_spec.stub(:stemcell).and_return(@stemcell_spec)
    @resource_pool_spec.stub(:name).and_return('test')
    @resource_pool_spec.stub(:cloud_properties).and_return({'ram' => '2gb'})
    @resource_pool_spec.stub(:env).and_return({})
    @resource_pool_spec.stub(:spec).and_return({'name' => 'foo'})

    @network_settings = {'network_a' => {'ip' => '1.2.3.4'}}
  end

  it 'should create a vm' do
    @cloud.should_receive(:create_vm).with(kind_of(String), 'stemcell-id', {'ram' => '2gb'}, @network_settings, nil, {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, nil, @resource_pool_spec.env)
    vm.deployment.should == @deployment
    Bosh::Director::Models::Vm.all.should == [vm]
  end

  it 'sets vm metadata' do
    @cloud.stub(create_vm: 'fake-vm-cid')

    vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
    Bosh::Director::VmMetadataUpdater.should_receive(:build).and_return(vm_metadata_updater)
    vm_metadata_updater.should_receive(:update) do |vm, metadata|
      vm.cid.should == 'fake-vm-cid'
      metadata.should == {}
    end

    Bosh::Director::VmCreator.new.create(
      @deployment, @stemcell, @resource_pool_spec.cloud_properties,
      @network_settings, nil, @resource_pool_spec.env)
  end


  it 'should create vm with disk' do
    @cloud.should_receive(:create_vm).with(kind_of(String), 'stemcell-id', {'ram' => '2gb'}, @network_settings, [99], {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99), @resource_pool_spec.env)
  end

  it 'should create credentials when encryption is enabled' do
    Bosh::Director::Config.encryption = true
    @cloud.should_receive(:create_vm).with(kind_of(String), 'stemcell-id',
                                           {'ram' => '2gb'}, @network_settings, [99],
                                           {'bosh' =>
                                             { 'credentials' =>
                                               { 'crypt_key' => kind_of(String),
                                                 'sign_key' => kind_of(String)}}})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

    Base64.strict_decode64(vm.credentials['crypt_key']).should be_kind_of(String)
    Base64.strict_decode64(vm.credentials['sign_key']).should be_kind_of(String)

    lambda {
      Base64.strict_decode64(vm.credentials['crypt_key'] + 'foobar')
    }.should raise_error(ArgumentError, /invalid base64/)

    lambda {
      Base64.strict_decode64(vm.credentials['sign_key'] + 'barbaz')
    }.should raise_error(ArgumentError, /invalid base64/)
  end

  it 'should retry creating a VM if it is told it is a retryable error' do
    @cloud.should_receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
    @cloud.should_receive(:create_vm).once

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, nil, @resource_pool_spec.env)

    vm.deployment.should == @deployment
    Bosh::Director::Models::Vm.all.should == [vm]
  end

  it 'should not retry creating a VM if it is told it is not a retryable error' do
    @cloud.should_receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                                @network_settings, nil, @resource_pool_spec.env)
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
    Bosh::Director::Config.max_vm_create_tries = 3

    @cloud.should_receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

    expect {
      vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                                @network_settings, nil, @resource_pool_spec.env)
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should have deep copy of environment' do
    Bosh::Director::Config.encryption = true
    env_id = nil

    @cloud.should_receive(:create_vm) do |*args|
      env_id = args[5].object_id
    end

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

    @cloud.should_receive(:create_vm) do |*args|
      args[5].object_id.should_not == env_id
    end

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

  end

end
