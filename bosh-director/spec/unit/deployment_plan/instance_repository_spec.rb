require 'spec_helper'

describe Bosh::Director::DeploymentPlan::InstanceRepository do
  subject(:instance_repository) { BD::DeploymentPlan::InstanceRepository.new(network_reservation_repository, logger) }
  let(:plan) do
    network = BD::DeploymentPlan::DynamicNetwork.new('name-7', [], logger)
    ip_repo = BD::DeploymentPlan::InMemoryIpRepo.new(logger)
    ip_provider = BD::DeploymentPlan::IpProvider.new(ip_repo, {'name-7' => network}, logger)
    model = BD::Models::Deployment.make
    instance_double('Bosh::Director::DeploymentPlan::Planner',
      network: network,
      ip_provider: ip_provider,
      model: model
    )
  end

  let(:job) do
    job = BD::DeploymentPlan::Job.new(logger)
    job.name = 'job-name'
    job
  end

  let(:network_reservation_repository) { Bosh::Director::DeploymentPlan::NetworkReservationRepository.new(plan, logger) }

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
  end

  describe '#fetch_existing' do
    let(:existing_instance) do
      Bosh::Director::Models::Instance.make(
        deployment_id: 'deployment-id',
        job: 'job-name',
        index: 1,
        state: 'started',
        compilation: false,
        uuid: 'uuid-2',
        availability_zone: 'az-name',
        bootstrap: false,
        spec: instance_spec
      )
    end
    let(:instance_spec) { {} }

    it 'returns an DeploymentPlan::Instance with a bound Models::Instance' do
      instance = instance_repository.fetch_existing(existing_instance, {}, job, nil, plan)

      expect(instance.model).to eq(existing_instance)
      expect(instance.uuid).to eq(existing_instance.uuid)
      expect(instance.state).to eq(existing_instance.state)
    end

    context 'when job has instance state' do
      it 'returns a DeploymentPlan::Instance with the state of the DesiredInstance' do
        job.instance_states[existing_instance.uuid] = 'job-state'
        instance = instance_repository.fetch_existing(existing_instance, {}, job, nil, plan)

        expect(instance.state).to eq('job-state')
        expect(instance.uuid).to eq(existing_instance.uuid)
      end
    end

    describe 'binding existing reservations' do
      context 'when instance has reservations in db' do
        before do
          existing_instance.add_ip_address(BD::Models::IpAddress.make(address: 123))
        end

        it 'is using reservation from database' do
          instance = instance_repository.fetch_existing(existing_instance, {}, job, nil, plan)
          expect(instance.existing_network_reservations.map(&:ip)).to eq([123])
        end
      end

      context 'when instance does not have reservations in database' do
        context 'when instance has reservations on dynamic networks' do
          let(:instance_spec) { {'networks' => {'name-7' => {'type' => 'dynamic', 'ip' => '10.10.0.10'}}} }

          it 'creates reservations from state' do
            instance = instance_repository.fetch_existing(existing_instance, {'networks' => {'name-7' => {'ip' => 345}}}, job, nil, plan)
            expect(instance.existing_network_reservations.map(&:ip)).to eq([345])
          end
        end

        context 'when binding reservations with state' do
          it 'creates reservations from state' do
            instance = instance_repository.fetch_existing(existing_instance, {'networks' => {'name-7' => {'ip' => 345}}}, job, nil, plan)
            expect(instance.existing_network_reservations.map(&:ip)).to eq([345])
          end
        end

        context 'when binding without state' do
          it 'has no reservations' do
            instance = instance_repository.fetch_existing(existing_instance, nil, job, nil, plan)
            expect(instance.existing_network_reservations.map(&:ip)).to eq([])
          end
        end
      end
    end
  end

  describe '#create' do
    it 'should persist an instance with attributes from the desired_instance' do
      az = BD::DeploymentPlan::AvailabilityZone.new('az-name', {})
      desired_instance = BD::DeploymentPlan::DesiredInstance.new(job, plan, az)

      instance_repository.create(desired_instance, 1)

      persisted_instance = BD::Models::Instance.find(uuid: 'uuid-1')
      expect(persisted_instance.deployment_id).to eq(plan.model.id)
      expect(persisted_instance.job).to eq(job.name)
      expect(persisted_instance.index).to eq(1)
      expect(persisted_instance.state).to eq('started')
      expect(persisted_instance.compilation).to eq(job.compilation?)
      expect(persisted_instance.uuid).to eq('uuid-1')
    end
  end
end
