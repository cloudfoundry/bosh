require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::UnresponsiveAgent do

    def make_handler(instance, cloud, _, data = {})
      handler = ProblemHandlers::UnresponsiveAgent.new(instance.id, data)
      allow(handler).to receive(:cloud).and_return(cloud)
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, @instance.agent_id, anything).and_return(@agent)
      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, @instance.agent_id).and_return(@agent)
      handler
    end

    before(:each) do
      @cloud = instance_double('Bosh::Cloud')
      @agent = double(Bosh::Director::AgentClient)
      allow(Config).to receive(:cloud).and_return(@cloud)

      deployment_model = Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.legacy_manifest))

      @instance = Models::Instance.make(
        job: 'mysql_node',
        index: 0,
        uuid: 'uuid-1',
        vm_cid: 'vm-cid',
        deployment: deployment_model,
        cloud_properties_hash: { 'foo' => 'bar' },
        spec: {'networks' => networks},
        agent_id: 'agent-007'
      )
      allow(Bosh::Director::Config).to receive(:current_job).and_return(job)
    end

    let(:event_manager) { Bosh::Director::Api::EventManager.new(true)}
    let(:job) {instance_double(Bosh::Director::Jobs::BaseJob, username: 'user', task_id: 42, event_manager: event_manager)}

    let(:networks) { {'A' => {'ip' => '1.1.1.1'}, 'B' => {'ip' => '2.2.2.2'}, 'C' => {'ip' => '3.3.3.3'}} }

    let :handler do
      make_handler(@instance, @cloud, @agent)
    end

    it 'registers under unresponsive_agent type' do
      handler = ProblemHandlers::Base.create_by_type(:unresponsive_agent, @instance.id, {})
      expect(handler).to be_kind_of(ProblemHandlers::UnresponsiveAgent)
    end

    it 'has well-formed description' do
      expect(handler.description).to eq('mysql_node/0 (uuid-1) (vm-cid) is not responding')
    end

    describe 'reboot_vm resolution' do
      it 'skips reboot if CID is not present' do
        @instance.update(vm_cid: nil)
        expect {
          handler.apply_resolution(:reboot_vm)
        }.to raise_error(ProblemHandlerError, /is no longer in the database/)
      end

      it 'skips reboot if agent is now alive' do
        expect(@agent).to receive(:ping).and_return(:pong)

        expect {
          handler.apply_resolution(:reboot_vm)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      it 'reboots VM' do
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)
        expect(@cloud).to receive(:reboot_vm).with('vm-cid')
        expect(@agent).to receive(:wait_until_ready)

        handler.apply_resolution(:reboot_vm)
      end

      it 'reboots VM and whines if it is still unresponsive' do
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)
        expect(@cloud).to receive(:reboot_vm).with('vm-cid')
        expect(@agent).to receive(:wait_until_ready).
          and_raise(RpcTimeout)

        expect {
          handler.apply_resolution(:reboot_vm)
        }.to raise_error(ProblemHandlerError, 'Agent still unresponsive after reboot')
      end
    end

    describe 'recreate_vm resolution' do
      it 'skips recreate if CID is not present' do
        @instance.update(vm_cid: nil)

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to raise_error(ProblemHandlerError, /is no longer in the database/)
      end

      it "doesn't recreate VM if agent is now alive" do
        allow(@agent).to receive_messages(ping: :pong)

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      context 'when no errors' do
        let(:spec) do
          {
            'deployment' => 'simple',
            'job' => {'name' => 'job'},
            'index' => 0,
            'vm_type' => {
              'name' => 'fake-vm-type',
              'cloud_properties' => { 'foo' => 'bar' },
            },
            'stemcell' => {
              'name' => 'stemcell-name',
              'version' => '3.0.2'
            },
            'networks' => networks,
            'template_hashes' => {},
            'configuration_hash' => {'configuration' => 'hash'},
            'rendered_templates_archive' => {'some' => 'template'},
            'env' => { 'key1' => 'value1' }
          }
        end
        let(:agent_spec) do
          {
            'deployment' => 'simple',
            'job' => {'name' => 'job'},
            'index' => 0,
            'networks' => networks,
            'template_hashes' => {},
            'configuration_hash' => {'configuration' => 'hash'},
            'rendered_templates_archive' => {'some' => 'template'}
          }
        end
        let(:fake_new_agent) { double(Bosh::Director::AgentClient) }

        before do
          Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
          @instance.update(spec: spec)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(@instance.credentials, 'agent-222', anything).and_return(fake_new_agent)
          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(@instance.credentials, 'agent-222').and_return(fake_new_agent)
          allow(SecureRandom).to receive_messages(uuid: 'agent-222')
          fake_app
          allow(App.instance.blobstores.blobstore).to receive(:create).and_return('fake-blobstore-id')
        end

        it 'recreates the VM' do
          allow(@agent).to receive(:ping).and_raise(RpcTimeout)

          expect(@cloud).to receive(:delete_vm).with('vm-cid')
          expect(@cloud).
            to receive(:create_vm).with('agent-222', 'sc-302', { 'foo' => 'bar' }, networks, [], { 'key1' => 'value1' })
                                  .and_return('new-vm-cid')

          expect(fake_new_agent).to receive(:wait_until_ready).ordered
          expect(fake_new_agent).to receive(:update_settings).ordered
          expect(fake_new_agent).to receive(:apply).with({'deployment' => 'simple', 'job' => {'name' => 'job'}, 'index' => 0, 'networks' => networks}).ordered
          expect(fake_new_agent).to receive(:get_state).and_return(agent_spec).ordered
          expect(fake_new_agent).to receive(:apply).with(agent_spec).ordered
          expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
          expect(fake_new_agent).to receive(:start).ordered

          expect(Models::Instance.find(agent_id: 'agent-007', vm_cid: 'vm-cid')).not_to be_nil
          expect(Models::Instance.find(agent_id: 'agent-222', vm_cid: 'new-vm-cid')).to be_nil

          handler.apply_resolution(:recreate_vm)

          expect(Models::Instance.find(agent_id: 'agent-007', vm_cid: 'vm-cid')).to be_nil
          expect(Models::Instance.find(agent_id: 'agent-222', vm_cid: 'new-vm-cid')).not_to be_nil
        end
      end
    end

    describe 'delete_vm_reference resolution' do

      it 'skips deleting VM ref if agent is now alive' do
        expect(@agent).to receive(:ping).and_return(:pong)

        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      it 'deletes VM reference' do
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)
        expect{
          handler.apply_resolution(:delete_vm_reference)
        }.to change {Models::Instance.where(vm_cid: 'vm-cid').count}.from(1).to(0)
      end
    end
  end
end
