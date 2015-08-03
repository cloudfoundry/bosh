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
  let(:availability_zone) do
    instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)
  end
  let(:resource_pool) { instance_double(Bosh::Director::DeploymentPlan::ResourcePool) }
  let(:instance) do
    allow(resource_pool).to receive(:env).and_return({})
    instance_double(
      Bosh::Director::DeploymentPlan::Instance,
      deployment_model: deployment,
      resource_pool: resource_pool,
      availability_zone: nil,
      network_settings: network_settings,
      model: Bosh::Director::Models::Instance.make(vm: nil),
      vm: Bosh::Director::DeploymentPlan::Vm.new,
      bind_to_vm_model: nil,
      apply_vm_state: nil,
      update_trusted_certs: nil,
    )
  end

  before do
    allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
    Bosh::Director::Config.max_vm_create_tries = 2
    allow(Bosh::Director::AgentClient).to receive(:with_vm).and_return(agent_client)

    stemcell = Bosh::Director::Models::Stemcell.make(:cid => 'stemcell-id')
    allow(resource_pool).to receive(:stemcell).and_return(stemcell)
    allow(resource_pool).to receive(:cloud_properties).and_return({'ram' => '2gb'})
  end

  it 'should create a vm' do
    expect(cloud).to receive(:create_vm).with(
      kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')

    allow(instance).to receive(:availability_zone) { nil }

    expect(instance).to receive(:bind_to_vm_model)
    expect(agent_client).to receive(:wait_until_ready)
    expect(instance).to receive(:apply_vm_state)
    expect(instance).to receive(:update_trusted_certs)

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(Bosh::Director::Models::Vm.all.size).to eq(1)
    expect(Bosh::Director::Models::Vm.first.cid).to eq('new-vm-cid')
  end

  describe 'cloud_properties the vm is created with' do
    context 'when the instance has an availability zone' do
      it 'merges the resource pool cloud properties into the availability zone cloud properties' do
        allow(cloud).to receive(:create_vm).and_return('new-vm-cid')

        allow(instance).to receive(:availability_zone) { availability_zone }
        allow(availability_zone).to receive(:cloud_properties).and_return({'foo' => 'az-foo', 'zone' => 'the-right-one' })
        allow(resource_pool).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

        subject.create_for_instance(instance, ['fake-disk-cid'])

        expect(cloud).to have_received(:create_vm).with(
            anything, anything,
            {'zone' => 'the-right-one', 'resources' => 'the-good-stuff', 'foo' => 'rp-foo'},
            anything, anything, anything
          )
      end
    end

    context 'when the instance does not have an availability zone' do
      it 'uses just the resource pool cloud properties' do
        allow(cloud).to receive(:create_vm).and_return('new-vm-cid')

        allow(instance).to receive(:availability_zone) { nil }
        allow(resource_pool).to receive(:cloud_properties).and_return({'foo' => 'rp-foo', 'resources' => 'the-good-stuff'})

        subject.create_for_instance(instance, ['fake-disk-cid'])

        expect(cloud).to have_received(:create_vm).with(
            anything, anything,
            {'foo' => 'rp-foo', 'resources' => 'the-good-stuff'},
            anything, anything, anything
          )
      end
    end
  end

  it 'sets vm metadata' do
    vm_metadata_updater = instance_double('Bosh::Director::VmMetadataUpdater')
    expect(Bosh::Director::VmMetadataUpdater).to receive(:build).and_return(vm_metadata_updater)
    expect(vm_metadata_updater).to receive(:update) do |vm, metadata|
      expect(vm.cid).to eq('new-vm-cid')
      expect(metadata).to eq({})
    end

    allow(instance).to receive(:availability_zone) { nil }

    expect(cloud).to receive(:create_vm).with(
        kind_of(String), 'stemcell-id', kind_of(Hash), network_settings, ['fake-disk-cid'], {}
      ).and_return('new-vm-cid')

    subject.create_for_instance(instance, ['fake-disk-cid'])
  end

  it 'should create credentials when encryption is enabled' do
    Bosh::Director::Config.encryption = true
    expect(cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
                                           kind_of(Hash), network_settings, ['fake-disk-cid'],
                                           {'bosh' =>
                                             { 'credentials' =>
                                               { 'crypt_key' => kind_of(String),
                                                 'sign_key' => kind_of(String)}}})

    allow(instance).to receive(:availability_zone) { nil }

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

    allow(instance).to receive(:availability_zone) { nil }

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(Bosh::Director::Models::Vm.first.cid).to eq('fake-vm-cid')
  end

  it 'should not retry creating a VM if it is told it is not a retryable error' do
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    allow(instance).to receive(:availability_zone) { nil }

    expect {
      subject.create_for_instance(instance, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
    Bosh::Director::Config.max_vm_create_tries = 3

    expect(cloud).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

    allow(instance).to receive(:availability_zone) { nil }

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

    allow(instance).to receive(:availability_zone) { nil }

    subject.create_for_instance(instance, ['fake-disk-cid'])

    expect(cloud).to receive(:create_vm) do |*args|
      expect(args[5].object_id).not_to eq(env_id)
    end

    subject.create_for_instance(instance, ['fake-disk-cid'])
  end
end
