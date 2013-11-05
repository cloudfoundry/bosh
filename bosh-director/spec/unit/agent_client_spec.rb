require 'spec_helper'

module Bosh::Director
  describe AgentClient do
    describe '.convert_old_message_to_new' do
      def convert_message_given_expects(given, expects)
        agent = AgentClient
        result = agent.convert_old_message_to_new(given)
        result.should == expects
      end

      it 'should leave a correctly formatted no-value response alone' do
        message = { 'state' => 'running', 'value' => nil, 'agent_task_id' => 1 }
        convert_message_given_expects(message, message)
      end

      it 'should leave a correctly formatted response alone' do
        message = { 'state' => 'running', 'value' => { 'key1' => 1, 'key2' => 2 },
                    'agent_task_id' => 1 }
        convert_message_given_expects(message, message)
      end

      it 'should fix a message that is not wrapped in value' do
        actual = { 'key1' => 1, 'key2' => 2 }
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should fix a message that is an array' do
        actual = [1, 2, 3]
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should fix a message that is in the old value format' do
        actual = { 'key1' => 1, 'key2' => 2 }
        expected = { 'state' => 'done', 'value' => { 'key1' => 1, 'key2' => 2 },
                     'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should fix a nil message' do
        actual = nil
        expected = { 'state' => 'done', 'value' => nil, 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should wrap a message that has no value' do
        actual = { 'state' => 'done', 'agent_task_id' => 1 }
        convert_message_given_expects(actual, actual)
      end

      it 'should fix a message that has no state or agent_task_id' do
        # If there was no state, then we are assuming this was the old message
        # format.
        actual = { 'value' => 'blah' }
        expected = { 'state' => 'done', 'value' => 'blah', 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should fix a message that has only a string' do
        actual = 'something'
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
      end

      it 'should fix a message that has only a float' do
        actual = 1.01
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        convert_message_given_expects(actual, expected)
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
