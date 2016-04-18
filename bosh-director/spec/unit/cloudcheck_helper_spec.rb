require 'spec_helper'

module Bosh::Director
  describe CloudcheckHelper do
    class TestProblemHandler < ProblemHandlers::Base
      register_as :test_problem_handler

      def initialize(instance_uuid, data)
        super
        @instance = Models::Instance.find(uuid: instance_uuid)
      end

      resolution :recreate_vm do
        action { recreate_vm(@instance) }
      end
    end

    let(:instance) do
      Models::Instance.make(
        deployment: deployment_model,
        job: 'mysql_node',
        index: 0,
        vm_cid: 'vm-cid',
        spec: {'apply' => 'spec', 'env' => {'vm_env' => 'json'}}
      )
    end
    let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.legacy_manifest), :name => 'name-1') }
    let(:test_problem_handler) { ProblemHandlers::Base.create_by_type(:test_problem_handler, instance.uuid, {}) }
    let(:fake_cloud) { instance_double('Bosh::Cloud') }
    let(:vm_deleter) { Bosh::Director::VmDeleter.new(fake_cloud, logger) }
    let(:vm_creator) { Bosh::Director::VmCreator.new(fake_cloud, logger, vm_deleter, nil, job_renderer, arp_flusher) }
    let(:arp_flusher) { instance_double(ArpFlusher)}
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:event_manager) {Api::EventManager.new(true)}
    let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager)}


    before do
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id, anything).and_return(agent_client)
      allow(VmDeleter).to receive(:new).and_return(vm_deleter)
      allow(VmCreator).to receive(:new).and_return(vm_creator)
      allow(fake_cloud).to receive(:create_vm)
      allow(fake_cloud).to receive(:delete_vm)
      allow(Config).to receive(:current_job).and_return(update_job)
      fake_app
    end

    def fake_job_context
      test_problem_handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
      allow(Config).to receive(:cloud).and_return(fake_cloud)
    end

    describe '#delete_vm' do
      before { fake_job_context }
      context 'when VM does not have disks' do
        before { allow(agent_client).to receive(:list_disk).and_return([]) }

        it 'deletes VM using vm_deleter' do
          expect(vm_deleter).to receive(:delete_vm).with(instance.vm_cid)
          test_problem_handler.delete_vm(instance)
        end
      end

      context 'when VM has disks' do
        before { allow(agent_client).to receive(:list_disk).and_return(['fake-disk-cid']) }

        it 'fails' do
          expect {
            test_problem_handler.delete_vm(instance)
          }.to raise_error 'VM has persistent disk attached'
        end
      end
    end

    describe '#recreate_vm' do
      describe 'error handling' do
        it "doesn't recreate VM if apply spec is unknown" do
          instance.update(spec_json: nil)

          expect {
              test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Unable to look up VM apply spec')
        end

        it 'whines on invalid spec format' do
          instance.update(spec: :foo)

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Invalid apply spec format')
        end

        it 'whines on invalid env format' do
          instance.update(spec: {'env' => 'bar'})

          expect {
            test_problem_handler.apply_resolution(:recreate_vm)
          }.to raise_error(ProblemHandlerError, 'Invalid VM environment format')
        end
      end

      describe 'actually recreating the VM' do
        let(:spec) do
          {
            'vm_type' => {
              'name' => 'vm-type',
              'cloud_properties' => {'foo' => 'bar'},
            },
            'stemcell' => {
              'name' => 'stemcell-name',
              'version' => '3.0.2'
            },
            'env' => {
              'key1' => 'value1'
            },
            'networks' => {
              'ip' => '192.1.3.4'
            }
          }
        end
        let(:fake_new_agent) { double('Bosh::Director::AgentClient') }
        let(:dns_manager) { instance_double(DnsManager) }
        before do
          BD::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
          instance.update(spec: spec)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id, anything).and_return(fake_new_agent)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id).and_return(fake_new_agent)

          allow(DnsManagerProvider).to receive(:create).and_return(dns_manager)
        end

        it 'recreates the VM' do
          fake_job_context

          expect(vm_deleter).to receive(:delete_for_instance) do |instance|
            expect(instance.cloud_properties_hash).to eq({'foo' => 'bar'})
            expect(instance.vm_env).to eq({'key1' => 'value1'})
          end

          expect(vm_creator).to receive(:create_for_instance_plan) do |instance_plan|
            expect(instance_plan.network_settings_hash).to eq({'ip' => '192.1.3.4'})
            expect(instance_plan.instance.cloud_properties).to eq({'foo' => 'bar'})
            expect(instance_plan.instance.env).to eq({'key1' => 'value1'})
          end

          expect(fake_new_agent).to receive(:apply).with({'networks' => {'ip' => '192.1.3.4'}}).ordered
          expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
          expect(fake_new_agent).to receive(:start).ordered

          expect(dns_manager).to receive(:dns_record_name).with(0, 'mysql_node', 'ip', 'name-1').and_return('index.record.name')
          expect(dns_manager).to receive(:dns_record_name).with(instance.uuid, 'mysql_node', 'ip', 'name-1').and_return('uuid.record.name')
          expect(dns_manager).to receive(:update_dns_record_for_instance).with(instance, {'index.record.name' =>nil, 'uuid.record.name' =>nil})
          expect(dns_manager).to receive(:flush_dns_cache)

          test_problem_handler.apply_resolution(:recreate_vm)
        end
      end
    end
  end
end
