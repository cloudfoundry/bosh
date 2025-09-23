require 'spec_helper'

module Bosh::Director
  describe CloudcheckHelper do
    include IpUtil

    class TestProblemHandler < ProblemHandlers::Base
      register_as :test_problem_handler

      def initialize(instance_uuid, data)
        super
        @instance = Models::Instance.find(uuid: instance_uuid)
      end

      resolution :recreate_vm do
        action { recreate_vm(@instance) }
      end

      resolution :recreate_vm_without_wait do
        action { recreate_vm_without_wait(@instance) }
      end
    end

    let(:instance) do
      instance = FactoryBot.create(:models_instance,
        deployment: deployment_model,
        job: 'mysql_node',
        index: 0,
        spec: spec,
        availability_zone: 'az1',
      )
      instance
    end

    let!(:ip_address) { FactoryBot.create(:models_ip_address, instance: instance, address_str: Bosh::Director::IpAddrOrCidr.new('192.1.3.4').to_s) }
    let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }

    let(:spec) do
      { 'apply' => 'spec', 'env' => { 'vm_env' => 'json' } }
    end

    let(:deployment_model) do
      manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      FactoryBot.create(:models_deployment, name: manifest['name'], manifest: YAML.dump(manifest))
    end

    let(:test_problem_handler) { ProblemHandlers::Base.create_by_type(:test_problem_handler, instance.uuid, {}) }
    let(:dns_encoder) { LocalDnsEncoderManager.create_dns_encoder(false) }
    let(:vm_deleter) { Bosh::Director::VmDeleter.new(per_spec_logger, false, false) }
    let(:vm_creator) do
      Bosh::Director::VmCreator.new(
        per_spec_logger,
        template_cache,
        dns_encoder,
        agent_broadcaster,
        planner.link_provider_intents,
      )
    end
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
    let(:template_cache) { Bosh::Director::Core::Templates::TemplateBlobCache.new }
    let(:agent_client) { instance_double(AgentClient) }
    let(:event_manager) { Api::EventManager.new(true) }
    let(:update_job) { instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: 42, event_manager: event_manager) }
    let(:rendered_templates_persister) { instance_double(RenderedTemplatesPersister) }

    let(:planner) do
      instance_double(
        Bosh::Director::DeploymentPlan::Planner,
        use_short_dns_addresses?: false,
        use_link_dns_names?: false,
        ip_provider: ip_provider,
        link_provider_intents: [],
        networks: [network],
      )
    end
    let(:network) { instance_double(Bosh::Director::DeploymentPlan::Network, name: ip_address.network_name) }

    let(:ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider) }
    let(:planner_factory) { instance_double(Bosh::Director::DeploymentPlan::PlannerFactory) }
    let!(:local_dns_blob) { FactoryBot.create(:models_local_dns_blob) }

    before do
      allow(AgentClient).to receive(:with_agent_id).with(instance.agent_id, instance.name, anything).and_return(agent_client)
      allow(AgentClient).to receive(:with_agent_id).with(instance.agent_id, instance.name).and_return(agent_client)

      allow(agent_client).to receive(:sync_dns) do |_, _, _, &blk|
        blk.call('value' => 'synced')
      end.and_return(0)

      allow(Bosh::Director::Core::Templates::TemplateBlobCache).to receive(:new).and_return(template_cache)

      allow(VmDeleter).to receive(:new).and_return(vm_deleter)
      allow(VmCreator).to receive(:new).and_return(vm_creator)

      allow(Config).to receive(:current_job).and_return(update_job)

      allow(RenderedTemplatesPersister).to receive(:new).and_return(rendered_templates_persister)

      allow(Bosh::Director::DeploymentPlan::PlannerFactory).to receive(:create).with(per_spec_logger).and_return(planner_factory)

      allow(planner_factory).to receive(:create_from_model).with(instance.deployment).and_return(planner)
      allow(planner).to receive(:network).with(network.name).and_return(network)

      allow(ip_provider).to receive(:reserve_existing_ips)

      fake_app
    end

    def fake_job_context
      test_problem_handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
    end

    describe '#reboot_vm' do
      let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
      let(:cloud_factory) { instance_double(CloudFactory) }
      before do
        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        expect(cloud).to receive(:reboot_vm).with(vm.cid)
        expect(cloud_factory).to receive(:get).with(instance.active_vm.cpi).and_return(cloud)
      end

      it 'reboots the vm on success' do
        allow(agent_client).to receive(:wait_until_ready)
        test_problem_handler.reboot_vm(instance)
      end

      it 'raises a ProblemHandlerError if agent is still unresponsive' do
        allow(agent_client).to receive(:wait_until_ready).and_raise(Bosh::Director::RpcTimeout)

        expect do
          test_problem_handler.reboot_vm(instance)
        end.to raise_error(ProblemHandlerError, 'Agent still unresponsive after reboot')
      end

      it 'raises a ProblemHandlerError if task is cancelled' do
        allow(agent_client).to receive(:wait_until_ready).and_raise(Bosh::Director::TaskCancelled)

        expect do
          test_problem_handler.reboot_vm(instance)
        end.to raise_error(ProblemHandlerError, 'Task was cancelled')
      end
    end

    describe '#delete_vm_reference' do
      before { fake_job_context }

      it 'deletes VM reference' do
        expect do
          test_problem_handler.delete_vm_reference(instance)
        end.to change {
          vm = Models::Vm.where(instance_id: instance.id).first
          vm.nil? ? 0 : Models::Vm.where(instance_id: instance.id, active: true).count
        }.from(1).to(0)
      end

      context 'instance active_vm is nil' do
        before do
          vm_model = instance.active_vm
          instance.active_vm = nil
          vm_model.delete
        end

        it 'does not error' do
          expect do
            test_problem_handler.delete_vm_reference(instance)
          end.to_not raise_error
        end
      end
    end

    describe '#delete_vm' do
      before { fake_job_context }
      context 'when VM does not have disks' do
        before { allow(agent_client).to receive(:list_disk).and_return([]) }

        it 'deletes VM using vm_deleter' do
          expect(vm_deleter).to receive(:delete_for_instance).with(instance)
          test_problem_handler.delete_vm(instance)
        end
      end

      context 'when VM has disks' do
        before { allow(agent_client).to receive(:list_disk).and_return(['fake-disk-cid']) }

        it 'fails' do
          expect do
            test_problem_handler.delete_vm(instance)
          end.to raise_error 'VM has persistent disk attached'
        end
      end
    end

    describe '#recreate_vm' do
      describe 'error handling' do
        it "doesn't recreate VM if apply spec is unknown" do
          instance.update(spec_json: nil)

          expect do
            test_problem_handler.apply_resolution(:recreate_vm)
          end.to raise_error(ProblemHandlerError, 'Unable to look up VM apply spec')
        end

        it 'whines on invalid spec format' do
          instance.update(spec_json: 'error')

          expect do
            test_problem_handler.apply_resolution(:recreate_vm)
          end.to raise_error(ProblemHandlerError, 'Invalid apply spec format')
        end

        it 'whines on invalid env format' do
          instance.update(spec: { 'env' => 'bar' })

          expect do
            test_problem_handler.apply_resolution(:recreate_vm)
          end.to raise_error(ProblemHandlerError, 'Invalid VM environment format')
        end
      end

      describe 'actually recreating the VM' do
        let(:spec) do
          {
            'vm_type' => {
              'name' => 'vm-type',
              'cloud_properties' => { 'foo' => 'bar' },
            },
            'stemcell' => {
              'name' => 'stemcell-name',
              'version' => '3.0.2',
            },
            'env' => {
              'key1' => 'value1',
            },
            'networks' => {
              'ip' => '192.1.3.4',
            },
          }
        end

        before do
          FactoryBot.create(:models_stemcell, name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
          instance.update(spec: spec)
        end

        context 'recreates the vm' do
          before { fake_job_context }

          def expect_vm_gets_created
            expect(vm_deleter).to receive(:delete_for_instance) do |instance|
              expect(instance.cloud_properties_hash).to eq('foo' => 'bar')
              expect(instance.vm_env).to eq('key1' => 'value1')
            end

            expect(vm_creator).to receive(:create_for_instance_plan) do |instance_plan, ipp, disks, tags, use_existing|
              expect(instance_plan.network_settings_hash).to eq('ip' => '192.1.3.4')
              expect(instance_plan.instance.cloud_properties).to eq('foo' => 'bar')
              expect(instance_plan.instance.env).to eq('key1' => 'value1')
              expect(ipp).to eq(ip_provider)
              expect(disks).to eq([])
              expect(tags).to eq({})
              expect(use_existing).to eq(true)
              expect(instance_plan.network_plans.count).to eq(1)
              expect(instance_plan.network_plans.first.existing?).to eq(true)
              expect(instance_plan.network_plans.first.reservation.ip).to eq(to_ipaddr('192.1.3.4'))
            end

            expect(rendered_templates_persister).to receive(:persist)

            expect(agent_client).to receive(:apply).with({ 'networks' => { 'ip' => '192.1.3.4' } }).ordered
            expect(agent_client).to receive(:run_script).with('pre-start', {}).ordered
            expect(agent_client).to receive(:start).ordered

            allow(Config).to receive(:root_domain).and_return('bosh')
            expect(Bosh::Director::DnsNameGenerator).to receive(:dns_record_name).with(0, 'mysql_node', 'ip', deployment_model.name, 'bosh').and_return('index.record.name')
            expect(Bosh::Director::DnsNameGenerator).to receive(:dns_record_name).with(instance.uuid, 'mysql_node', 'ip', deployment_model.name, 'bosh').and_return('uuid.record.name')

            expect(template_cache).to receive(:clean_cache!)
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
                  'cloud_properties' => { 'foo' => 'bar' },
                },
                'stemcell' => {
                  'name' => 'stemcell-name',
                  'version' => '3.0.2',
                },
                'env' => {
                  'key1' => 'value1',
                },
                'networks' => {
                  'ip' => '192.1.3.4',
                },
                'update' => {
                  'canaries' => 1,
                  'max_in_flight' => 10,
                  'canary_watch_time' => '1000-30000',
                  'update_watch_time' => '1000-30000',
                },
              }
            end

            before do
              allow(agent_client).to receive(:get_state).and_return('job_state' => 'running')
            end

            it 'skips running post start when applying recreate_vm_without_wait resolution' do
              expect_vm_gets_created
              expect(agent_client).to_not receive(:run_script).with('post-start', {})
              test_problem_handler.apply_resolution(:recreate_vm_without_wait)
            end

            it 'runs post start when applying recreate_vm resolution' do
              expect_vm_gets_created
              expect(agent_client).to receive(:run_script).with('post-start', {})
              test_problem_handler.apply_resolution(:recreate_vm)
            end
          end
        end
      end
    end
  end
end
