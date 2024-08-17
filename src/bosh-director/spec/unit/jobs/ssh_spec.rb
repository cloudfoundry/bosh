require 'spec_helper'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe Jobs::Ssh do
    include FakeFS::SpecHelpers

    subject(:job) do
      described_class.new(deployment.id, 'target' => target, 'command' => 'fake-command', 'params' => { 'user' => 'user-ssh' })
    end

    let(:deployment) { FactoryBot.create(:models_deployment, name: 'name-1') }
    let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment) }
    let(:target) do
      { 'job' => 'fake-job', 'indexes' => [1] }
    end
    let(:agent) { double(AgentClient) }
    let(:config) { double(Config) }
    let(:instance_manager) { Api::InstanceManager.new }
    let(:task_result) { TaskDBWriter.new(:result_output, task.id) }
    let(:task) {FactoryBot.create(:models_task, id: 42, username: 'user')}

    describe 'DJ job class expectations' do
      let(:job_type) { :ssh }
      let(:queue) { :urgent }
      it_behaves_like 'a DJ job'
    end

    before do
      is = FactoryBot.create(:models_instance, job: 'fake-job', index: 1, variable_set: variable_set, deployment: deployment, uuid: 'fake-uuid-1')
      vm = Models::Vm.make(cid: 'cid', instance_id: is.id)
      is.active_vm = vm
      FactoryBot.create(:models_instance, job: 'fake-job', index: 2, variable_set: variable_set, deployment: deployment, uuid: 'fake-uuid-2')
      allow(Api::InstanceManager).to receive(:new).and_return(instance_manager)
      allow(instance_manager).to receive(:agent_client_for).and_return(agent)
      allow(agent).to receive(:ssh).and_return({})
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Config).to receive(:record_events).and_return(true)
      allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40Z'))
      Config.default_ssh_options = {'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}
      Config.result = task_result
    end

    def parsed_task_result
      JSON.parse(Models::Task.first(id: 42).result_output)
    end

    it 'returns default_ssh_options if they exist' do
      job.perform

      expect(parsed_task_result).to eq([{'index' => 1, 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap', 'id' => "fake-uuid-1", 'job' => 'fake-job'}])
    end

    context 'when instance does not have vm' do
      let(:target) do
        { 'job' => 'fake-job', 'indexes' => [1, 2] }
      end

      it 'performs only for instances with vm' do
        instance_with_vm = Models::Instance.reject { |instance| instance.active_vm.nil? }.first
        instance_witout_vm = Models::Instance.reject { |instance| !instance.active_vm.nil? }.first
        expect(instance_manager).to_not receive(:agent_client_for).with(instance_witout_vm)
        expect(instance_manager).to receive(:agent_client_for).with(instance_with_vm)
        job.perform
      end
    end

    it 'should store new event' do
      expect { job.perform }.to change { Models::Event.count }.from(0).to(1)
      event = Models::Event.first
      expect(event.user).to eq(task.username)
      expect(event.action).to eq('fake-command ssh')
      expect(event.object_type).to eq('instance')
      expect(event.object_name).to eq('fake-job/fake-uuid-1')
      expect(event.deployment).to eq('name-1')
      expect(event.instance).to eq('fake-job/fake-uuid-1')
      expect(event.task).to eq("#{task.id}")
      expect(event.context).to eq({'user' => 'user-ssh'})
      expect(event.timestamp).to eq(Time.now)
    end

    it 'should store event with error' do
      allow(instance_manager).to receive(:agent_client_for).and_raise(InstanceVmMissing, 'error')
      expect { job.perform }.to raise_error(InstanceVmMissing)
      event = Models::Event.first
      expect(event.error).to eq('error')
    end

    context 'when instance id was passed in' do
      let(:target) do
        { 'job' => 'fake-job', 'ids' => ['fake-uuid-1'] }
      end

      context 'when id is instance uuid' do
        it 'finds instance by its id and generates response with id' do
          job.perform
          expect(parsed_task_result).to eq([{'id' => 'fake-uuid-1', 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap', 'job' => 'fake-job', 'index' => 1}])
        end

        it 'stores event with instance uuid' do
          job.perform
          event = Bosh::Director::Models::Event.first
          expect(event.instance).to eq('fake-job/fake-uuid-1')
        end
      end

      context 'when id is instance index' do
        let(:target) do
          { 'job' => 'fake-job', 'ids' => [1] }
        end

        it 'finds instance by its index and generates response with id' do
          job.perform
          expect(parsed_task_result).to eq([{'id' => 'fake-uuid-1', 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap', 'job' => 'fake-job', 'index' => 1}])
        end

        it 'stores event with instance index' do
          job.perform
          event = Bosh::Director::Models::Event.first
          expect(event.instance).to eq('fake-job/fake-uuid-1')
        end
      end
    end
  end
end
