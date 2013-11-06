require 'spec_helper'

module Bosh::Director
  describe AgentClient do
    describe 'long-runnings messages' do
      let(:vm) do
        instance_double('Models::Vm', credentials: nil)
      end

      subject(:client) do
        AgentClient.new('fake-agent_id')
      end

      before do
        Models::Vm.stub(:find).with(agent_id: 'fake-agent_id').and_return(vm)
        Config.stub(:nats_rpc)
        Api::ResourceManager.stub(:new)
      end

      it 'explicitly defines methods for long running messages (to poll their tasks)' do
        expect(client.methods).to include(
                                    :prepare,
                                    :apply,
                                    :compile_package,
                                    :drain,
                                    :fetch_logs,
                                    :migrate_disk,
                                    :mount_disk,
                                    :stop,
                                    :unmount_disk,
                                  )
      end
    end

    describe 'ping <=> pong' do
      let(:stemcell) do
        Models::Stemcell.make(:cid => 'stemcell-id')
      end

      let(:network_settings) do
        { 'network_a' => { 'ip' => '1.2.3.4' } }
      end

      let(:vm) do
        cloud = double('cloud')
        Config.stub(:cloud).and_return(cloud)
        env = {}
        deployment = Models::Deployment.make
        cloud_properties = { 'ram' => '2gb' }
        cloud.stub(:create_vm).with(kind_of(String), 'stemcell-id',
                                    { 'ram' => '2gb' }, network_settings, [99],
                                    { 'bosh' =>
                                        { 'credentials' =>
                                            { 'crypt_key' => kind_of(String),
                                              'sign_key' => kind_of(String) } } })
        VmCreator.new.create(deployment, stemcell,
                             cloud_properties,
                             network_settings, Array(99),
                             env)
      end

      subject(:client) do
        AgentClient.new(vm.agent_id)
      end

      it 'should use vm credentials' do
        nats_rpc = double('nats_rpc')

        Config.stub(:nats_rpc).and_return(nats_rpc)
        Config.encryption = true

        App.stub(instance: double('App Instance').as_null_object)

        handler = Bosh::Core::EncryptionHandler.new(vm.agent_id, vm.credentials)
        nats_rpc.should_receive(:send_request) do |*args, &blk|
          data = args[1]['encrypted_data']
          handler.decrypt(data) # decrypt to initiate session
          blk.call('encrypted_data' => handler.encrypt('value' => 'pong'))
        end

        expect(client.ping).to eq('pong')
      end
    end
  end
end
