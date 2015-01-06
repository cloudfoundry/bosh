require 'spec_helper'

describe Bosh::Director::VmCreator do

  before do
    @cloud = instance_double('Bosh::Cloud')
    allow(Bosh::Director::Config).to receive(:cloud).and_return(@cloud)
    Bosh::Director::Config.max_vm_create_tries = 2

    @deployment = Bosh::Director::Models::Deployment.make

    @deployment_plan = double('deployment_plan')
    allow(@deployment_plan).to receive(:deployment).and_return(@deployment)
    allow(@deployment_plan).to receive(:name).and_return('deployment_name')

    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => 'stemcell-id')

    @stemcell_spec = double('stemcell_spec')
    allow(@stemcell_spec).to receive(:stemcell).and_return(@stemcell)

    @resource_pool_spec = double('resource_pool_spec')
    allow(@resource_pool_spec).to receive(:deployment).and_return(@deployment_plan)
    allow(@resource_pool_spec).to receive(:stemcell).and_return(@stemcell_spec)
    allow(@resource_pool_spec).to receive(:name).and_return('test')
    allow(@resource_pool_spec).to receive(:cloud_properties).and_return({'ram' => '2gb'})
    allow(@resource_pool_spec).to receive(:env).and_return({})
    allow(@resource_pool_spec).to receive(:spec).and_return({'name' => 'foo'})

    @network_settings = {'network_a' => {'ip' => '1.2.3.4'}}
  end

  it 'should create a vm' do
    expect(@cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id', {'ram' => '2gb'}, @network_settings, nil, {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, nil, @resource_pool_spec.env)
    expect(vm.deployment).to eq(@deployment)
    expect(Bosh::Director::Models::Vm.all).to eq([vm])
  end

  it 'sets vm metadata' do
    allow(@cloud).to receive_messages(create_vm: 'fake-vm-cid')

    vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
    expect(Bosh::Director::VmMetadataUpdater).to receive(:build).and_return(vm_metadata_updater)
    expect(vm_metadata_updater).to receive(:update) do |vm, metadata|
      expect(vm.cid).to eq('fake-vm-cid')
      expect(metadata).to eq({})
    end

    Bosh::Director::VmCreator.new.create(
      @deployment, @stemcell, @resource_pool_spec.cloud_properties,
      @network_settings, nil, @resource_pool_spec.env)
  end


  it 'should create vm with disk' do
    expect(@cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id', {'ram' => '2gb'}, @network_settings, [99], {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99), @resource_pool_spec.env)
  end

  it 'should create credentials when encryption is enabled' do
    Bosh::Director::Config.encryption = true
    expect(@cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
                                           {'ram' => '2gb'}, @network_settings, [99],
                                           {'bosh' =>
                                             { 'credentials' =>
                                               { 'crypt_key' => kind_of(String),
                                                 'sign_key' => kind_of(String)}}})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

    expect(Base64.strict_decode64(vm.credentials['crypt_key'])).to be_kind_of(String)
    expect(Base64.strict_decode64(vm.credentials['sign_key'])).to be_kind_of(String)

    expect {
      Base64.strict_decode64(vm.credentials['crypt_key'] + 'foobar')
    }.to raise_error(ArgumentError, /invalid base64/)

    expect {
      Base64.strict_decode64(vm.credentials['sign_key'] + 'barbaz')
    }.to raise_error(ArgumentError, /invalid base64/)
  end

  it 'should retry creating a VM if it is told it is a retryable error' do
    expect(@cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
    expect(@cloud).to receive(:create_vm).once

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, nil, @resource_pool_spec.env)

    expect(vm.deployment).to eq(@deployment)
    expect(Bosh::Director::Models::Vm.all).to eq([vm])
  end

  it 'should not retry creating a VM if it is told it is not a retryable error' do
    expect(@cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                                @network_settings, nil, @resource_pool_spec.env)
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
    Bosh::Director::Config.max_vm_create_tries = 3

    expect(@cloud).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

    expect {
      vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                                @network_settings, nil, @resource_pool_spec.env)
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should have deep copy of environment' do
    Bosh::Director::Config.encryption = true
    env_id = nil

    expect(@cloud).to receive(:create_vm) do |*args|
      env_id = args[5].object_id
    end

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

    expect(@cloud).to receive(:create_vm) do |*args|
      expect(args[5].object_id).not_to eq(env_id)
    end

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

  end

end
