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

      resolution :recreate_vm_skip_post_start do
        action { recreate_vm_skip_post_start(@instance) }
      end
    end

    let(:instance) do
      Models::Instance.make(
        deployment: deployment_model,
        job: 'mysql_node',
        index: 0,
        vm_cid: 'vm-cid',
        spec: spec,
        availability_zone: 'az1'
      )
    end
    let(:spec) { {'apply' => 'spec', 'env' => {'vm_env' => 'json'}} }
    let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.legacy_manifest), :name => 'name-1') }
    let(:test_problem_handler) { ProblemHandlers::Base.create_by_type(:test_problem_handler, instance.uuid, {}) }
    let(:vm_deleter) { Bosh::Director::VmDeleter.new(logger, false, false) }
    let(:vm_creator) { Bosh::Director::VmCreator.new(logger, vm_deleter, nil, job_renderer, agent_broadcaster) }
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
    let(:job_renderer) { instance_double(JobRenderer) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:event_manager) { Api::EventManager.new(true) }
    let(:update_job) { instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager) }
    let(:dns_manager) { instance_double(DnsManager) }
    let(:rendered_templates_persister) { instance_double(RenderedTemplatesPersister) }

    before do
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id, anything).and_return(agent_client)
      allow(VmDeleter).to receive(:new).and_return(vm_deleter)
      allow(VmCreator).to receive(:new).and_return(vm_creator)
      allow(Config).to receive(:current_job).and_return(update_job)
      allow(RenderedTemplatesPersister).to receive(:new).and_return(rendered_templates_persister)
      fake_app
    end

    def fake_job_context
      test_problem_handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
    end

    describe '#reboot_vm' do
      let(:cloud) { Config.cloud }
      let(:cloud_factory) { instance_double(CloudFactory) }
      before do
        allow(CloudFactory).to receive(:new).and_return(cloud_factory)
        expect(cloud).to receive(:reboot_vm).with(instance.vm_cid)
        expect(cloud_factory).to receive(:for_availability_zone).with(instance.availability_zone).and_return(cloud)
      end

      it 'reboots the vm on success' do
        allow(agent_client).to receive(:wait_until_ready)
        test_problem_handler.reboot_vm(instance)
      end

      it 'raises a ProblemHandlerError if agent is still unresponsive' do
        allow(agent_client).to receive(:wait_until_ready).and_raise(Bosh::Director::RpcTimeout)

        expect {
          test_problem_handler.reboot_vm(instance)
        }.to raise_error(ProblemHandlerError, 'Agent still unresponsive after reboot')
      end

      it 'raises a ProblemHandlerError if task is cancelled' do
        allow(agent_client).to receive(:wait_until_ready).and_raise(Bosh::Director::TaskCancelled)

        expect {
          test_problem_handler.reboot_vm(instance)
        }.to raise_error(ProblemHandlerError, 'Task was cancelled')
      end
    end

    describe '#delete_vm' do
      before { fake_job_context }
      context 'when VM does not have disks' do
        before { allow(agent_client).to receive(:list_disk).and_return([]) }

        it 'deletes VM using vm_deleter' do
          expect(vm_deleter).to receive(:delete_vm).with(instance)
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
          instance.update(spec_json: 'error')

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
        before do
          BD::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
          instance.update(spec: spec)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id, anything).and_return(fake_new_agent)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id).and_return(fake_new_agent)

          allow(DnsManagerProvider).to receive(:create).and_return(dns_manager)
        end


        context 'recreates the vm' do

          before { fake_job_context }

          def expect_vm_gets_created
            expect(vm_deleter).to receive(:delete_for_instance) do |instance|
              expect(instance.cloud_properties_hash).to eq({'foo' => 'bar'})
              expect(instance.vm_env).to eq({'key1' => 'value1'})
            end

            expect(vm_creator).to receive(:create_for_instance_plan) do |instance_plan|
              expect(instance_plan.network_settings_hash).to eq({'ip' => '192.1.3.4'})
              expect(instance_plan.instance.cloud_properties).to eq({'foo' => 'bar'})
              expect(instance_plan.instance.env).to eq({'key1' => 'value1'})
            end

            expect(rendered_templates_persister).to receive(:persist)

            expect(fake_new_agent).to receive(:apply).with({'networks' => {'ip' => '192.1.3.4'}}).ordered
            expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
            expect(fake_new_agent).to receive(:start).ordered

            expect(dns_manager).to receive(:dns_record_name).with(0, 'mysql_node', 'ip', 'name-1').and_return('index.record.name')
            expect(dns_manager).to receive(:dns_record_name).with(instance.uuid, 'mysql_node', 'ip', 'name-1').and_return('uuid.record.name')
            expect(dns_manager).to receive(:update_dns_record_for_instance).with(instance, {'index.record.name' => nil, 'uuid.record.name' => nil})
            expect(dns_manager).to receive(:flush_dns_cache)
          end

          it 'recreates the VM' do
            expect_vm_gets_created
            test_problem_handler.apply_resolution(:recreate_vm)
          end

          context 'when update is specified' do
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
                },
                'update' => {
                  'canaries' => 1,
                  'max_in_flight' => 10,
                  'canary_watch_time' => '1000-30000',
                  'update_watch_time' => '1000-30000'
                }
              }
            end

            it 'skips running post start when applying recreate_vm_skip_post_start resolution' do
              expect_vm_gets_created
              expect(fake_new_agent).to_not receive(:run_script).with('post-start', {})
              test_problem_handler.apply_resolution(:recreate_vm_skip_post_start)
            end

            it 'runs post start when applying recreate_vm resolution' do
              allow(fake_new_agent).to receive(:get_state).and_return({'job_state' => 'running'})
              expect_vm_gets_created
              expect(fake_new_agent).to receive(:run_script).with('post-start', {})
              test_problem_handler.apply_resolution(:recreate_vm)
            end
          end
        end
      end
    end
  end
end
