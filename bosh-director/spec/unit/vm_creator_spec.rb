require 'spec_helper'

describe Bosh::Director::VmCreator do
  subject  {Bosh::Director::VmCreator.new(cloud, logger, vm_deleter)}

  let(:cloud) { instance_double('Bosh::Cloud') }
  let(:vm_deleter) {Bosh::Director::VmDeleter.new(cloud, logger)}
  let(:agent_client) do
    instance_double(
      Bosh::Director::AgentClient,
      wait_until_ready: nil,
      update_settings: nil,
    )
  end
  let(:network_settings) { {'network_a' => {'ip' => '1.2.3.4'}} }
  let(:deployment) { Bosh::Director::Models::Deployment.make }
  let(:deployment_plan) do
    instance_double(Bosh::Director::DeploymentPlan::Planner, model: deployment, name: 'deployment_name')
  end
  let(:instance) do
    resource_pool = instance_double(Bosh::Director::DeploymentPlan::ResourcePool)
    stemcell = Bosh::Director::Models::Stemcell.make(:cid => 'stemcell-id')
    allow(resource_pool).to receive(:stemcell).and_return(stemcell)
    allow(resource_pool).to receive(:cloud_properties).and_return({'ram' => '2gb'})
    allow(resource_pool).to receive(:env).and_return({})
    instance_double(
      Bosh::Director::DeploymentPlan::Instance,
      deployment_model: deployment,
      resource_pool: resource_pool,
      network_settings: network_settings,
      model: Bosh::Director::Models::Instance.make(vm: nil),
      vm: Bosh::Director::DeploymentPlan::Vm.new,
      bind_to_vm_model: nil,
      apply_vm_state: nil
    )
  end

  before do
    allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
    Bosh::Director::Config.max_vm_create_tries = 2
    allow(Bosh::Director::AgentClient).to receive(:with_vm).and_return(agent_client)
  end

  it 'should create a vm' do
    expect(cloud).to receive(:create_vm).with(
      kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')

    expect(instance).to receive(:bind_to_vm_model)
    expect(agent_client).to receive(:wait_until_ready)
    expect(agent_client).to receive(:update_settings)
    expect(instance).to receive(:apply_vm_state)

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(Bosh::Director::Models::Vm.all.size).to eq(1)
    expect(Bosh::Director::Models::Vm.first.cid).to eq('new-vm-cid')
  end

  it 'sets vm metadata' do
    vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
    expect(Bosh::Director::VmMetadataUpdater).to receive(:build).and_return(vm_metadata_updater)
    expect(vm_metadata_updater).to receive(:update) do |vm, metadata|
      expect(vm.cid).to eq('new-vm-cid')
      expect(metadata).to eq({})
    end

    expect(cloud).to receive(:create_vm).with(
        kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {}
      ).and_return('new-vm-cid')

    subject.create_for_instance(instance, ['fake-disk-cid'])
  end

  it 'should create credentials when encryption is enabled' do
    Bosh::Director::Config.encryption = true
    expect(cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
                                           {'ram' => '2gb'}, network_settings, ['fake-disk-cid'],
                                           {'bosh' =>
                                             { 'credentials' =>
                                               { 'crypt_key' => kind_of(String),
                                                 'sign_key' => kind_of(String)}}})

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(Bosh::Director::Models::Vm.all.size).to eq(1)
    vm = Bosh::Director::Models::Vm.first

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
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
    expect(cloud).to receive(:create_vm).once.and_return('fake-vm-cid')

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(Bosh::Director::Models::Vm.first.cid).to eq('fake-vm-cid')
  end

  it 'should not retry creating a VM if it is told it is not a retryable error' do
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      subject.create_for_instance(instance, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
    Bosh::Director::Config.max_vm_create_tries = 3

    expect(cloud).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

    expect {
      subject.create_for_instance(instance, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should have deep copy of environment' do
    Bosh::Director::Config.encryption = true
    env_id = nil

    expect(cloud).to receive(:create_vm) do |*args|
      env_id = args[5].object_id
    end

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(cloud).to receive(:create_vm) do |*args|
      expect(args[5].object_id).not_to eq(env_id)
    end

    subject.create_for_instance(instance, ['fake-disk-cid'])
  end
end
