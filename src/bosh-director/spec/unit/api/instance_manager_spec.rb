require 'spec_helper'

module Bosh::Director
  describe Api::InstanceManager do
    let(:deployment) { Models:: Deployment.make(name: deployment_name) }
    let(:active_vm) { true }
    let!(:vm) { Models::Vm.make(agent_id: 'random-id', instance_id: instance.id, active: active_vm) }
    let(:instance) { Models::Instance.make(uuid: 'fakeId123', deployment: deployment, job: job) }
    let!(:vm_1) { Models::Vm.make(agent_id: 'random-id1', instance_id: instance_1.id, active: active_vm) }
    let(:instance_1) { Models::Instance.make(uuid: 'fakeId124', deployment: deployment, job: job) }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:instance_lookup) { Api::InstanceLookup.new }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }
    let(:options) { { foo: 'bar' } }
    let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
    let(:job) { 'FAKE_JOB' }

    before do
      allow(JobQueue).to receive(:new).and_return(job_queue)
    end

    describe '#fetch_logs' do
      context 'when index is provided' do
        let(:index) { '3' }
        before { instance.update(index: index) }

        it 'enqueues a background job' do
          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [[instance.id], options], deployment).and_return(task)

          expect(subject.fetch_logs(username, deployment, job, index, options)).to eq(task)
        end

        context 'when no active_vm' do
          let(:active_vm) { false }
          it 'raises an error' do
            expect{ subject.fetch_logs(username, deployment, job, index, options) }.to raise_error(RuntimeError, "No appropriate instance with a VM was found in deployment 'FAKE_DEPLOYMENT_NAME'")
          end
        end
      end

      context 'when uuid is provided' do
        let(:uuid) { 'fakeId123' }

        it 'enqueues a job' do
          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [[instance.id], options], deployment).and_return(task)
          expect(subject.fetch_logs(username, deployment, job, uuid, options)).to eq(task)
        end

        context 'when no active_vm' do
          let(:active_vm) { false }
          it 'raises an error' do
            expect{ subject.fetch_logs(username, deployment, job, uuid, options) }.to raise_error(RuntimeError, "No appropriate instance with a VM was found in deployment 'FAKE_DEPLOYMENT_NAME'")
          end
        end
      end

      context 'when job is provided' do
        it 'enqueues a job' do
          expect(job_queue).to receive(:enqueue).with(
              username, Jobs::FetchLogs, 'fetch logs', [contain_exactly(instance.id, instance_1.id), options], deployment).and_return(task)
          expect(subject.fetch_logs(username, deployment, job, nil, options)).to eq(task)
        end

        context 'when no active_vm' do
          let(:active_vm) { false }
          it 'raises an error' do
            expect{ subject.fetch_logs(username, deployment, job, nil, options) }.to raise_error(RuntimeError, "No appropriate instance with a VM was found in deployment 'FAKE_DEPLOYMENT_NAME'")
          end
        end

        context 'when some vms are active' do
          let(:active_vm) { false }

          it 'enqueues a job' do
            instance_2 = Models::Instance.make(uuid: 'fakeId125', deployment: deployment, job: job)
            Models::Vm.make(agent_id: 'random-id2', instance_id: instance_2.id, active: true)

            expect(job_queue).to receive(:enqueue).with(
              username, Jobs::FetchLogs, 'fetch logs', [[instance_2.id], options], deployment).and_return(task)
            expect(subject.fetch_logs(username, deployment, job, nil, options)).to eq(task)
          end
        end
      end

      context 'when development is provided' do
        let!(:instance_2) do
          instance = Models::Instance.make(uuid: 'fakeId125', deployment: deployment, job: job_2)
          Models::Vm.make(agent_id: 'random-id2', instance_id: instance.id, active: active_vm)
          instance
        end
        let(:job_2) { 'FAKE_JOB_2' }

        it 'enqueues a job' do
          expect(job_queue).to receive(:enqueue).with(
              username, Jobs::FetchLogs, 'fetch logs', [contain_exactly(instance.id, instance_1.id, instance_2.id), options], deployment).and_return(task)

          expect(subject.fetch_logs(username, deployment, nil, nil, options)).to eq(task)
        end

        context 'when no active_vm' do
          let(:active_vm) { false }
          it 'raises an error' do
            expect{ subject.fetch_logs(username, deployment, nil, nil, options) }.to raise_error(RuntimeError, "No appropriate instance with a VM was found in deployment 'FAKE_DEPLOYMENT_NAME'")
          end
        end

        context 'when some vms are active' do
          let(:active_vm) { false }
          let(:job_3) { 'FAKE_JOB_3' }

          it 'enqueues a job' do
            instance_2 = Models::Instance.make(uuid: 'fakeId126', deployment: deployment, job: job_3)
            Models::Vm.make(agent_id: 'random-id3', instance_id: instance_2.id, active: true)

            expect(job_queue).to receive(:enqueue).with(
              username, Jobs::FetchLogs, 'fetch logs', [[instance_2.id], options], deployment).and_return(task)
            expect(subject.fetch_logs(username, deployment, nil, nil, options)).to eq(task)
          end
        end
      end
    end

    describe '#ssh' do
      let(:deployment_lookup) { Api::DeploymentLookup.new }
      let(:options) do
        {
          'deployment_name' => deployment_name,
          'command' => 'COMMAND',
          'target' => 'TARGET'
        }
      end

      it 'enqueues a DJ job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::Ssh, 'ssh: COMMAND:TARGET', [deployment.id, options], deployment).and_return(task)

        expect(subject.ssh(username, deployment, options)).to eq(task)
      end
    end

    describe '#find_instance' do
      it 'finds instance by id' do
        expect(subject.find_instance(instance.id)).to eq instance
      end
    end

    describe '#find_instances_by_deployment' do
      it 'uses InstanceLookup#by_deployment' do
        deployment = Models::Deployment.make(name: 'given_deployment')

        expect_any_instance_of(Api::InstanceLookup).to receive(:by_deployment).with(deployment)

        subject.find_instances_by_deployment(deployment)
      end
    end

    describe '#find_by_name' do
      let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
      let(:job) { 'FAKE_JOB' }
      let(:index) { 3 }
      let(:id) { '9A0A5D0E-868A-431C-A6EA-9E8EDF4DBF81' }

      it 'finds instance by deployment name, job name and index or id' do
        instance.update(index: index)
        instance.update(uuid: id)

        expect(subject.find_by_name(deployment, job, index)).to eq instance
        expect(subject.find_by_name(deployment, job, id)).to eq instance
      end
    end

    describe '#filter_by' do
      it 'filters by given criteria' do
        expect(subject.filter_by(deployment, uuid: instance.uuid).all).to eq [instance]
      end
    end

    describe '#agent_client_for' do
      it 'creates an agent client for the specified instance' do
        fake_agent_client = instance_double(AgentClient)
        expect(AgentClient).to receive(:with_agent_id).with(vm.agent_id).and_return(fake_agent_client)
        agent_client = subject.agent_client_for(instance)
        expect(agent_client).to eq(fake_agent_client)
      end

      context 'when the instance has no active vm' do
        let(:active_vm) { false }
        it 'raises error' do
          expect{ subject.agent_client_for(instance_1) }.to raise_error(InstanceVmMissing, "'#{instance_1}' doesn't reference a VM")
        end
      end
    end

    describe '#fetch_instances_with_vm' do
      before { allow(JobQueue).to receive(:new).and_return(job_queue) }

      it 'enqueues a DJ job' do
        allow(Dir).to receive_messages(mktmpdir: 'FAKE_TMPDIR')

        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT'], deployment).and_return(task)

        expect(subject.fetch_instances_with_vm(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end

    describe '#fetch_vms_by_instances' do
      before { allow(JobQueue).to receive(:new).and_return(job_queue) }

      it 'enqueues a DJ job' do
        allow(Dir).to receive_messages(mktmpdir: 'FAKE_TMPDIR')

        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT'], deployment).and_return(task)

        expect(subject.fetch_instances_with_vm(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end

    describe '#fetch_instances' do

      before { allow(JobQueue).to receive(:new).and_return(job_queue) }

      it 'enqueues a DJ job' do
        allow(Dir).to receive_messages(mktmpdir: 'FAKE_TMPDIR')

        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT', true], deployment).and_return(task)

        expect(subject.fetch_instances(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end

    describe '#vms_by_instances_for_deployment' do
      let!(:inactive_vm) { Models::Vm.make(instance: instance, active: false) }

      it 'reports all vms in that deployment and their associated instances' do
        results = subject.vms_by_instances_for_deployment(deployment)
        expect(results).to eq({
          instance => [ vm, inactive_vm ],
          instance_1 => [ vm_1 ]
        })
      end
    end
  end
end
