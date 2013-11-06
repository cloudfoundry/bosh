require 'spec_helper'

module Bosh::Director
  describe AgentClient do
    shared_examples_for 'a long running message' do |message_name|
      describe "##{message_name}" do
        let(:task) do
          {
            'agent_task_id' => 'fake-agent_task_id',
            'state' => 'running',
            'value' => 'task value'
          }
        end

        before do
          client.stub(send_message: task)
          client.stub(:get_task) do
            task['state'] = 'no longer running'
            task
          end

          client.stub(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
        end

        it 'explicitly defines methods for long running messages (to poll)' do
          expect(client).to respond_to(message_name)
        end

        it 'decorates the original send_message implementation' do
          client.public_send(message_name, 'fake', 'args')

          expect(client).to have_received(:send_message).with(message_name, 'fake', 'args')
        end

        it 'periodically polls the task while it is running' do
          client.public_send(message_name, 'fake', 'args')

          expect(client).to have_received(:get_task).with('fake-agent_task_id')
        end

        it 'stops polling once the task is no longer running' do
          task['state'] = 'something other than running'
          client.public_send(message_name, 'fake', 'args')

          expect(client).not_to have_received(:get_task)
        end

        it 'returns the task value' do
          expect(client.public_send(message_name, 'fake', 'args')).to eq('task value')
        end
      end
    end

    describe 'long running messages' do
      let(:vm) do
        instance_double('Models::Vm', credentials: nil)
      end

      subject(:client) do
        AgentClient.with_defaults('fake-agent_id')
      end

      before do
        Models::Vm.stub(:find).with(agent_id: 'fake-agent_id').and_return(vm)
        Config.stub(:nats_rpc)
        Api::ResourceManager.stub(:new)
      end

      include_examples 'a long running message', :prepare
      include_examples 'a long running message', :apply
      include_examples 'a long running message', :compile_package
      include_examples 'a long running message', :drain
      include_examples 'a long running message', :fetch_logs
      include_examples 'a long running message', :migrate_disk
      include_examples 'a long running message', :mount_disk
      include_examples 'a long running message', :stop
      include_examples 'a long running message', :unmount_disk
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
        AgentClient.with_defaults(vm.agent_id)
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
