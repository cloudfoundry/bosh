require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstanceRepository do
  include Bosh::Director::IpUtil

  let(:logger) { Logging::Logger.new('log') }
  subject(:instance_repository) { Bosh::Director::DeploymentPlan::InstanceRepository.new(logger, variables_interpolator) }
  let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

  let(:network) { Bosh::Director::DeploymentPlan::DynamicNetwork.new('name-7', [], logger) }

  let(:deployment_plan) do
    ip_repo = Bosh::Director::DeploymentPlan::IpRepo.new(logger)
    ip_provider = Bosh::Director::DeploymentPlan::IpProvider.new(ip_repo, { 'name-7' => network }, logger)
    model = Bosh::Director::Models::Deployment.make
    Bosh::Director::Models::VariableSet.create(deployment: model)
    instance_double(
      'Bosh::Director::DeploymentPlan::Planner',
      network: network,
      networks: [network],
      ip_provider: ip_provider,
      model: model,
    )
  end

  let(:desired_instance) { Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment_plan, nil, 0) }

  let(:instance_group) do
    Bosh::Director::DeploymentPlan::InstanceGroup.make(name: 'job-name')
  end

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
  end

  let(:existing_instance) do
    Bosh::Director::Models::Instance.make(spec: instance_spec)
  end

  describe '#fetch_existing' do
    let(:instance_spec) do
      {}
    end

    it 'returns an DeploymentPlan::Instance with a bound Models::Instance' do
      instance = instance_repository.fetch_existing(existing_instance, {}, desired_instance)

      expect(instance.model).to eq(existing_instance)
      expect(instance.uuid).to eq(existing_instance.uuid)
      expect(instance.state).to eq(existing_instance.state)
    end

    it 'returns an instance with correct current state' do
      instance = instance_repository.fetch_existing(existing_instance, { 'job_state' => 'unresponsive' }, desired_instance)
      expect(instance.model).to eq(existing_instance)
      expect(instance.current_job_state).to eq('unresponsive')
    end

    context 'when instance_group has instance state' do
      it 'returns a DeploymentPlan::Instance with the state of the DesiredInstance' do
        instance_group.instance_states[existing_instance.uuid] = 'job-state'
        instance = instance_repository.fetch_existing(existing_instance, {}, desired_instance)

        expect(instance.state).to eq('job-state')
        expect(instance.uuid).to eq(existing_instance.uuid)
      end
    end

    describe 'binding existing reservations' do
      context 'when instance has reservations in db' do
        before do
          existing_instance.add_ip_address(Bosh::Director::Models::IpAddress.make(address_str: '123'))
        end

        it 'is using reservation from database' do
          instance = instance_repository.fetch_existing(existing_instance, {}, desired_instance)
          expect(instance.existing_network_reservations.map(&:ip)).to eq([123])
        end
      end
    end
  end

  describe '#build_instance_from_model' do
    let(:stemcell) { Bosh::Director::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302') }
    let(:existing_instance) { BD::Models::Instance.make(state: 'started') }

    let(:instance_spec) do
      {
        'stemcell' => {
          'name' => stemcell.name,
          'version' => stemcell.version,
        },
        'env' => { 'key1' => 'value1' },
        'networks' => {
          'name-7' => {
            'ip' => '192.168.50.6',
            'type' => 'dynamic',
          },
        },
      }
    end

    it 'returns the instance last persisted in the database' do
      allow(existing_instance).to receive(:spec).and_return(instance_spec)
      instance = instance_repository.build_instance_from_model(
        existing_instance,
        { 'job_state' => 'stopped' },
        'started',
        deployment_plan,
      )

      expect(instance.model).to eq(existing_instance)
      expect(instance.uuid).to eq(existing_instance.uuid)
      expect(instance.state).to eq('started')
      expect(instance.current_job_state).to eq('stopped')
      expect(instance.existing_network_reservations.count).to eq(1)
      expect(instance.existing_network_reservations.first.ip).to eq(ip_to_i('192.168.50.6'))
    end
  end

  describe '#fetch_obsolete_existing' do
    let(:env) do
      {
        'key1' => 'value1',
      }
    end
    let(:stemcell) { Bosh::Director::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302') }
    let(:instance_spec) do
      {
        'vm_type' => {
          'name' => 'vm-type',
          'cloud_properties' => { 'foo' => 'bar' },
        },
        'stemcell' => {
          'name' => stemcell.name,
          'version' => stemcell.version,
        },
        'env' => env,
        'networks' => {
          'ip' => '192.168.1.1',
        },
      }
    end

    context 'when existing instances has VMs' do
      before do
        existing_instance.active_vm = Bosh::Director::Models::Vm.make(agent_id: 'scool', instance_id: existing_instance.id)
      end

      it 'returns an instance with a bound Models::Instance' do
        instance = instance_repository.fetch_obsolete_existing(existing_instance, {}, deployment_plan)

        expect(instance.model).to eq(existing_instance)
        expect(instance.uuid).to eq(existing_instance.uuid)
        expect(instance.state).to eq(existing_instance.state)
        expect(instance.index).to eq(existing_instance.index)
        expect(instance.availability_zone.name).to eq(existing_instance.availability_zone)
        expect(instance.compilation?).to eq(existing_instance.compilation)
        expect(instance.instance_group_name).to eq(existing_instance.job)
        expect(instance.stemcell.models.first).to eq(stemcell)
        expect(instance.env).to eq(env)
      end
    end

    it 'returns an instance with correct current state' do
      instance = instance_repository.fetch_obsolete_existing(
        existing_instance,
        { 'job_state' => 'unresponsive' },
        deployment_plan,
      )
      expect(instance.model).to eq(existing_instance)
      expect(instance.current_job_state).to eq('unresponsive')
    end

    context 'when existing instance does NOT have a VM' do
      it 'Models::Instance should not have a stemcell' do
        instance = instance_repository.fetch_obsolete_existing(existing_instance, {}, deployment_plan)

        expect(instance.stemcell).to be_nil
      end
    end

    context 'when existing instance has no spec' do
      let(:instance_spec) do
        {}
      end
      it 'returns an instance with no spec' do
        instance = instance_repository.fetch_obsolete_existing(existing_instance, {}, deployment_plan)
        expect(instance.model).to eq(existing_instance)
        expect(instance.uuid).to eq(existing_instance.uuid)
        expect(instance.state).to eq(existing_instance.state)
        expect(instance.index).to eq(existing_instance.index)
        expect(instance.availability_zone.name).to eq(existing_instance.availability_zone)
        expect(instance.compilation?).to eq(existing_instance.compilation)
        expect(instance.instance_group_name).to eq(existing_instance.job)
        expect(instance.stemcell).to be_nil
        expect(instance.env).to eq({})
      end
    end
    context 'binding existing reservations' do
      context 'when instance has reservations in db' do
        before do
          existing_instance.add_ip_address(Bosh::Director::Models::IpAddress.make(address_str: '123'))
        end

        it 'is using reservation from database' do
          instance = instance_repository.fetch_obsolete_existing(existing_instance, {}, deployment_plan)
          expect(instance.existing_network_reservations.map(&:ip)).to eq([123])
        end
      end
    end
  end

  describe '#create' do
    it 'should persist an instance with attributes from the desired_instance' do
      az = Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-name', {})
      desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group, deployment_plan, az)

      instance_repository.create(desired_instance, 1)

      persisted_instance = Bosh::Director::Models::Instance.find(uuid: 'uuid-1')
      expect(persisted_instance.deployment_id).to eq(deployment_plan.model.id)
      expect(persisted_instance.job).to eq(instance_group.name)
      expect(persisted_instance.index).to eq(1)
      expect(persisted_instance.state).to eq('started')
      expect(persisted_instance.compilation).to eq(instance_group.compilation?)
      expect(persisted_instance.uuid).to eq('uuid-1')
    end
  end
end
