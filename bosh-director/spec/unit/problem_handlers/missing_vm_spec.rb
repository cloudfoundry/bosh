require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::MissingVM do
    let(:manifest) { Bosh::Spec::Deployments.legacy_manifest }
    let(:deployment_model) { Models::Deployment.make(manifest: YAML.dump(manifest)) }
    let!(:instance) do
      Models::Instance.make(
        job: manifest['jobs'].first['name'],
        index: 0,
        deployment: deployment_model,
        cloud_properties_hash: {'foo' => 'bar'},
        spec: spec.merge({env: {'key1' => 'value1'}}),
        agent_id: 'agent-007',
        vm_cid: 'vm-cid'
      )
    end
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
      fake_app
      allow(App.instance.blobstores.blobstore).to receive(:create).and_return('fake-blobstore-id')
    end

    it 'registers under missing_vm type' do
      expect(handler).to be_kind_of(described_class)
    end

    it 'should call recreate_vm when set to auto' do
      allow(handler).to receive(:recreate_vm)
      expect(handler).to receive(:recreate_vm).with(instance)
      handler.auto_resolve
    end

    it 'has description' do
      expect(handler.description).to match(/VM with cloud ID 'vm-cid' missing./)
    end

    describe 'Resolutions:' do
      let(:fake_cloud) { instance_double('Bosh::Cloud') }
      let(:fake_new_agent) { double('Bosh::Director::AgentClient') }

      def fake_job_context
        handler.job = instance_double('Bosh::Director::Jobs::BaseJob')
        Bosh::Director::Config.current_job.task_id = 42
        allow(Config).to receive_messages(cloud: fake_cloud)
      end

      it 'recreates a VM' do
        Bosh::Director::Models::Task.make(:id => 42, :username => 'user')
        prepare_deploy(manifest, manifest)

        allow(SecureRandom).to receive_messages(uuid: 'agent-222')
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(fake_new_agent)

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
          with('agent-222', Bosh::Director::Models::Stemcell.all.first.cid, { 'foo' => 'bar' }, anything, [], { 'key1' => 'value1' }).
          and_return('new-vm-cid')

        fake_job_context

        expect(Models::Instance.find(agent_id: 'agent-007', vm_cid: 'vm-cid')).not_to be_nil
        expect(Models::Instance.find(agent_id: 'agent-222', vm_cid: 'new-vm-cid')).to be_nil

        handler.apply_resolution(:recreate_vm)

        expect(Models::Instance.find(agent_id: 'agent-007', vm_cid: 'vm-cid')).to be_nil
        expect(Models::Instance.find(agent_id: 'agent-222', vm_cid: 'new-vm-cid')).not_to be_nil
      end

      it 'deletes VM reference' do
        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to change { Models::Instance.where(vm_cid: 'vm-cid').count}.from(1).to(0)
      end
    end
  end
end
