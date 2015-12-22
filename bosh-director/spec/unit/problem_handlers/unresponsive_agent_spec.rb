require 'spec_helper'

module Bosh::Director
  describe ProblemHandlers::UnresponsiveAgent do

    RSpec::Matchers.define :vm_with_agent_id do |agent_id|
      match do |actual|
        actual.agent_id == agent_id
      end
    end

    def make_handler(vm, cloud, _, data = {})
      handler = ProblemHandlers::UnresponsiveAgent.new(vm.id, data)
      allow(handler).to receive(:cloud).and_return(cloud)
      allow(AgentClient).to receive(:with_vm).with(vm_with_agent_id(@vm.agent_id), anything).and_return(@agent)
      allow(AgentClient).to receive(:with_vm).with(vm_with_agent_id(@vm.agent_id)).and_return(@agent)
      handler
    end

    before(:each) do
      @cloud = instance_double('Bosh::Cloud')
      @agent = double(Bosh::Director::AgentClient)
      allow(Config).to receive(:cloud).and_return(@cloud)

      deployment_model = Models::Deployment.make(manifest: YAML.dump(Bosh::Spec::Deployments.legacy_manifest))

      @vm = Models::Vm.create(cid: 'vm-cid', agent_id: 'agent-007', deployment: deployment_model)
      @instance = Models::Instance.make(job: 'mysql_node', index: 0, vm: @vm, deployment: deployment_model, cloud_properties_hash: { 'foo' => 'bar' }, spec: {'networks' => networks})
    end

    let(:networks) { {'A' => {'ip' => '1.1.1.1'}, 'B' => {'ip' => '2.2.2.2'}, 'C' => {'ip' => '3.3.3.3'}} }

    let :handler do
      make_handler(@vm, @cloud, @agent)
    end

    it 'registers under unresponsive_agent type' do
      handler = ProblemHandlers::Base.create_by_type(:unresponsive_agent, @vm.id, {})
      expect(handler).to be_kind_of(ProblemHandlers::UnresponsiveAgent)
    end

    it 'has well-formed description' do
      expect(handler.description).to eq('mysql_node/0 (vm-cid) is not responding')
    end

    describe 'reboot_vm resolution' do
      it 'skips reboot if CID is not present' do
        @vm.update(cid: nil)
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)
        expect {
          handler.apply_resolution(:reboot_vm)
        }.to raise_error(ProblemHandlerError, /doesn't have a cloud id/)
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
        @vm.update(cid: nil)
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)

        expect {
          handler.apply_resolution(:recreate_vm)
        }.to raise_error(ProblemHandlerError, /doesn't have a cloud id/)
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
            'rendered_templates_archive' => {'some' => 'template'}
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
          @vm.update(env: { 'key1' => 'value1' })
          allow(AgentClient).to receive(:with_vm).with(vm_with_agent_id('agent-222'), anything).and_return(fake_new_agent)
          allow(AgentClient).to receive(:with_vm).with(vm_with_agent_id('agent-222')).and_return(fake_new_agent)
          allow(SecureRandom).to receive_messages(uuid: 'agent-222')
          fake_app
          allow(App.instance.blobstores.blobstore).to receive(:create).and_return('fake-blobstore-id')
        end

        it 'recreates the VM' do
          allow(@agent).to receive(:ping).and_raise(RpcTimeout)

          expect(@cloud).to receive(:delete_vm).with('vm-cid')
          expect(@cloud).
            to receive(:create_vm).with('agent-222', 'sc-302', { 'foo' => 'bar' }, networks, [], { 'key1' => 'value1' })

          expect(fake_new_agent).to receive(:wait_until_ready).ordered
          expect(fake_new_agent).to receive(:update_settings).ordered
          expect(fake_new_agent).to receive(:apply).with({'deployment' => 'simple', 'job' => {'name' => 'job'}, 'index' => 0, 'networks' => networks}).ordered
          expect(fake_new_agent).to receive(:get_state).and_return(agent_spec).ordered
          expect(fake_new_agent).to receive(:apply).with(agent_spec).ordered
          expect(fake_new_agent).to receive(:run_script).with('pre-start', {}).ordered
          expect(fake_new_agent).to receive(:start).ordered

          expect(Models::Vm.find(agent_id: 'agent-007')).not_to be_nil

          handler.apply_resolution(:recreate_vm)

          expect(Models::Vm.find(agent_id: 'agent-007')).to be_nil
        end
      end
    end

    describe 'delete_vm_reference resolution' do

      it 'skips deleting VM ref if agent is now alive' do
        @vm.update(cid: nil)
        expect(@agent).to receive(:ping).and_return(:pong)

        expect {
          handler.apply_resolution(:delete_vm_reference)
        }.to raise_error(ProblemHandlerError, 'Agent is responding now, skipping resolution')
      end

      it 'deletes VM reference' do
        @vm.update(cid: nil)
        expect(@agent).to receive(:ping).and_raise(RpcTimeout)
        handler.apply_resolution(:delete_vm_reference)
        expect(Models::Vm[@vm.id]).to be_nil
      end
    end
  end
end
