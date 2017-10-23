require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::MissingVM do
    let(:planner) { instance_double(Bosh::Director::DeploymentPlan::Planner, use_short_dns_addresses?: false) }
    let(:planner_factory) { instance_double(Bosh::Director::DeploymentPlan::PlannerFactory) }
    let(:manifest) { Bosh::Spec::Deployments.legacy_manifest }
    let(:deployment_model) { Models::Deployment.make(name: manifest['name'], manifest: YAML.dump(manifest)) }
    let!(:local_dns_blob) { Models::LocalDnsBlob.make }

    let!(:instance) do
      instance = Models::Instance.make(
        job: manifest['jobs'].first['name'],
        index: 0,
        uuid: '1234-5678',
        deployment: deployment_model,
        cloud_properties_hash: {'foo' => 'bar'},
        spec: spec.merge({env: {'key1' => 'value1'}}),
      )
      vm = Models::Vm.make(
        agent_id: 'agent-007',
        cid: vm_cid,
        instance_id: instance.id
      )

      instance.active_vm = vm
      instance.save
    end
    let(:vm_cid) { 'vm-cid' }
    let(:handler) { ProblemHandlers::Base.create_by_type(:missing_vm, instance.id, {}) }
    let(:spec) do
      {
        'deployment' => 'simple',
        'job' => {'name' => 'job'},
        'index' => 0,
        'vm_type' => {
          'name' => 'steve',
          'cloud_properties' => { 'foo' => 'bar' },
        },
        'stemcell' => manifest['resource_pools'].first['stemcell'],
        'networks' => networks
      }
    end
    let(:networks) { {'a' => {'ip' => '192.168.1.2'}} }

    before do
      allow(Bosh::Director::DeploymentPlan::PlannerFactory).to receive(:create).with(logger).and_return(planner_factory)
      allow(planner_factory).to receive(:create_from_model).with(instance.deployment).and_return(planner)
      fake_app
      allow(App.instance.blobstores.blobstore).to receive(:create).and_return('fake-blobstore-id')
    end

    it 'registers under missing_vm type' do
      expect(handler).to be_kind_of(described_class)
    end

    it 'should call recreate_vm_skip_post_start when set to auto' do
      allow(handler).to receive(:recreate_vm_skip_post_start)
      expect(handler).to receive(:recreate_vm_skip_post_start).with(instance)
      handler.auto_resolve
    end

    describe '#description' do
      context 'when vm cid is given' do
        it 'includes instance job name, uuid, index and vm cid' do
          expect(handler.description).to eq("VM for 'foobar/1234-5678 (0)' with cloud ID 'vm-cid' missing.")
        end
      end

      context 'when vm cid is nil' do
        let(:vm_cid) { nil }
        it 'includes instance job name, uuid, index but no vm cid' do
          expect(handler.description).to eq("VM for 'foobar/1234-5678 (0)' missing.")
        end
      end
    end

    describe 'Resolutions:' do
      let(:fake_cloud) { instance_double('Bosh::Cloud') }
      let(:fake_new_agent) { double('Bosh::Director::AgentClient') }

      before do
        allow(fake_new_agent).to receive(:sync_dns) do |_,_,_,&blk|
          blk.call({'value' => 'synced'})
        end.and_return(0)
      end

      def fake_job_context
        handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
        Bosh::Director::Config.current_job.task_id = 42
        Bosh::Director::Config.name = 'fake-director-name'
        allow(Config).to receive_messages(cloud: fake_cloud)
      end

      def expect_vm_to_be_created
        Bosh::Director::Models::Task.make(:id => 42, :username => 'user')
        prepare_deploy(manifest, manifest)

        allow(SecureRandom).to receive_messages(uuid: 'agent-222')
        allow(AgentClient).to receive(:with_agent_id).and_return(fake_new_agent)

        expect(fake_new_agent).to receive(:wait_until_ready).ordered
        expect(fake_new_agent).to receive(:update_settings).ordered
        expect(fake_new_agent).to receive(:apply).with(anything).ordered
        expect(fake_new_agent).to receive(:get_state).and_return(spec).ordered
        expect(fake_new_agent).to receive(:apply).with(anything).ordered
        expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
        expect(fake_new_agent).to receive(:start).ordered

        expect(fake_cloud).to receive(:delete_vm).with(instance.vm_cid)
        expect(fake_cloud).
          to receive(:create_vm).
            with('agent-222', Bosh::Director::Models::Stemcell.all.first.cid, {'foo' => 'bar'}, anything, [], {'key1' => 'value1', 'bosh' => {'group' => String, 'groups' => anything}}).
            and_return('new-vm-cid')

        fake_job_context

        expect(Models::Vm.find(agent_id: 'agent-007', cid: 'vm-cid')).not_to be_nil
        expect(Models::Vm.find(agent_id: 'agent-222', cid: 'new-vm-cid')).to be_nil
      end

      it 'recreates a VM ' do
        expect_vm_to_be_created
        handler.apply_resolution(:recreate_vm)
        expect(Models::Vm.find(agent_id: 'agent-007', cid: 'vm-cid')).to be_nil
        expect(Models::Vm.find(agent_id: 'agent-222', cid: 'new-vm-cid')).not_to be_nil
      end

      context 'when update is specified' do
        let(:spec) do
          {
            'deployment' => 'simple',
            'job' => {'name' => 'job'},
            'index' => 0,
            'vm_type' => {
              'name' => 'steve',
              'cloud_properties' => { 'foo' => 'bar' },
            },
            'stemcell' => manifest['resource_pools'].first['stemcell'],
            'networks' => networks,
            'update' => {
              'canaries' => 1,
              'max_in_flight' => 10,
              'canary_watch_time' => '1000-30000',
              'update_watch_time' => '1000-30000'
            }
          }
        end

        describe 'recreate_vm_skip_post_start' do

          it 'has a plan' do
            plan_summary = handler.instance_eval(&ProblemHandlers::MissingVM.plan_for(:recreate_vm_skip_post_start))
            expect(plan_summary).to eq('Recreate VM without waiting for processes to start')
          end

          it 'recreates a VM and skips post_start script' do
            expect_vm_to_be_created
            expect(fake_new_agent).to_not receive(:run_script).with('post-start', {})
            handler.apply_resolution(:recreate_vm_skip_post_start)

            expect(Models::Vm.find(agent_id: 'agent-007', cid: 'vm-cid')).to be_nil
            expect(Models::Vm.find(agent_id: 'agent-222', cid: 'new-vm-cid')).not_to be_nil
          end
        end

        describe 'recreate_vm' do

          it 'has a plan' do
            plan_summary = handler.instance_eval(&ProblemHandlers::MissingVM.plan_for(:recreate_vm))
            expect(plan_summary).to eq('Recreate VM and wait for processes to start')
          end

          it 'recreates a VM and runs post_start script' do
            allow(fake_new_agent).to receive(:get_state).and_return({'job_state' => 'running'})

            expect_vm_to_be_created
            expect(fake_new_agent).to receive(:run_script).with('post-start', {}).ordered
            handler.apply_resolution(:recreate_vm)

            expect(Models::Vm.find(agent_id: 'agent-007', cid: 'vm-cid')).to be_nil
            expect(Models::Vm.find(agent_id: 'agent-222', cid: 'new-vm-cid')).not_to be_nil
          end
        end

      end

      it 'deletes VM reference' do
        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to change {
          vm = Models::Vm.where(cid: 'vm-cid').first
          vm.nil? ? 0 : Models::Vm.where(instance_id: instance.id, active: true).count
        }.from(1).to(0)
      end
    end
  end
end
