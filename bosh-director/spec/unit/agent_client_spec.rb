require 'spec_helper'

module Bosh::Director
  describe AgentClient do
    def self.it_acts_as_asynchronous_message(message_name)
      describe "##{message_name}" do
        let(:task) do
          {
            'agent_task_id' => 'fake-agent_task_id',
            'state' => 'running',
            'value' => 'task value'
          }
        end

        before do
          allow(client).to receive_messages(handle_message_with_retry: task)
          allow(client).to receive(:get_task) do
            task['state'] = 'no longer running'
            task
          end

          allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
        end

        it 'explicitly defines methods for long running messages (to poll)' do
          expect(client).to respond_to(message_name)
        end

        it 'decorates the original send_message implementation' do
          client.public_send(message_name, 'fake', 'args')
          expect(client).to have_received(:handle_message_with_retry).with(message_name, 'fake', 'args')
        end

        it 'periodically polls the task while it is running' do
          client.public_send(message_name, 'fake', 'args')
          expect(client).to have_received(:get_task).with('fake-agent_task_id')
        end

        it 'stops polling once the task is no longer running' do
          task['state'] = 'something other than running'
          client.public_send(message_name, 'fake', 'args')
          expect(client).to have_received(:get_task).with('fake-agent_task_id').exactly(1).times
        end

        it 'returns the task value' do
          expect(client.public_send(message_name, 'fake', 'args')).to eq('task value')
        end
      end
    end


    def self.it_acts_as_synchronous_message(message_name)
      describe "##{message_name}" do
        let(:task) do
          {
            'state' => 'running',
            'value' => 'task value'
          }
        end

        before do
          allow(client).to receive_messages(handle_message_with_retry: task)
          allow(client).to receive(:wait_for_task)

          allow(client).to receive(:get_task) do
            task['state'] = 'no longer running'
            task
          end
        end

        it 'does not wait for task' do
          expect(client).not_to have_received(:wait_for_task)
        end

        it 'returns the task value' do
          expect(client.public_send(message_name, 'fake', 'args')).to eq('task value')
        end
      end
    end

    context 'task is asynchronous' do
      describe 'it has agent_task_id' do
        subject(:client) { AgentClient.with_defaults('fake-agent_id') }
        let(:vm_model) { instance_double('Bosh::Director::Models::Vm', credentials: nil, agent_id: 'fake-agent_id') }
        let(:task) do
          {
              'agent_task_id' => 'fake-agent_task_id',
              'state' => 'running',
              'value' => 'task value'
          }
        end

        before do
          allow(Models::Vm).to receive(:find).with(agent_id: 'fake-agent_id').and_return(vm_model)
        end

        describe 'send asynchronous messages' do

          before do
            allow(Config).to receive(:nats_rpc)
            allow(Api::ResourceManager).to receive(:new)
          end

          it_acts_as_asynchronous_message :prepare
          it_acts_as_asynchronous_message :apply
          it_acts_as_asynchronous_message :compile_package
          it_acts_as_asynchronous_message :drain
          it_acts_as_asynchronous_message :fetch_logs
          it_acts_as_asynchronous_message :migrate_disk
          it_acts_as_asynchronous_message :mount_disk
          it_acts_as_asynchronous_message :unmount_disk
          it_acts_as_asynchronous_message :configure_networks
          it_acts_as_asynchronous_message :stop
          it_acts_as_asynchronous_message :cancel_task
          it_acts_as_asynchronous_message :list_disk
          it_acts_as_asynchronous_message :prepare_network_change
          it_acts_as_asynchronous_message :prepare_configure_networks
          it_acts_as_asynchronous_message :start
        end

        describe 'update_settings' do
          it 'packages the certificates into a map and sends to the agent' do
            expect(client).to receive(:send_message).with(:update_settings, "trusted_certs" => "these are the certificates")
            allow(client).to receive(:get_task)
            client.update_settings("these are the certificates")
          end

          it 'periodically polls the update settings task while it is running' do
            allow(client).to receive(:handle_message_with_retry).and_return task
            allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
            expect(client).to receive(:get_task).with('fake-agent_task_id')
            client.update_settings("these are the certificates")
          end

          it 'is only a warning when the remote agent does not implement update_settings' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "unknown message update_settings")

            expect(Config.logger).to receive(:warn).with("Ignoring update_settings 'unknown message' error from the agent: #<Bosh::Director::RpcRemoteException: unknown message update_settings>")
            expect { client.update_settings("no certs") }.to_not raise_error
          end

          it 'still raises an exception for other RPC failures' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "random failure!")

            expect(client).to_not receive(:warning)
            expect { client.update_settings("no certs") }.to raise_error
          end
        end

        describe 'run_script' do
          it 'sends the script name to the agent' do
            expect(client).to receive(:send_message).with(:run_script, "script_name", {})
            allow(client).to receive(:get_task)
            client.run_script("script_name", {})
          end

          it 'periodically polls the run_script task while it is running' do
            allow(client).to receive(:handle_message_with_retry).and_return task
            allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
            expect(client).to receive(:get_task).with('fake-agent_task_id')
            client.run_script("script_name", {})
          end

          it 'is only a warning when the remote agent does not implement run_script' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "unknown message run_script")

            expect(Config.logger).to receive(:warn).with("Ignoring run_script 'unknown message' error from the agent: #<Bosh::Director::RpcRemoteException: unknown message run_script>." +
            " Received while trying to run: script_name")
            expect { client.run_script("script_name", {})}.to_not raise_error
          end

          it 'still raises an exception for other RPC failures' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "random failure wooooooow!")

            expect(client).to_not receive(:warning)
            expect { client.run_script("script_name", {}) }.to raise_error
          end
        end

      end
    end

    context 'task is synchronous' do
      describe 'it does not have agent_task_id' do
        subject(:client) { AgentClient.with_defaults('fake-agent_id') }

        before { allow(Models::Vm).to receive(:find).with(agent_id: 'fake-agent_id').and_return(vm_model) }
        let(:vm_model) { instance_double('Bosh::Director::Models::Vm', credentials: nil, agent_id: 'fake-agent_id') }

        before do
          allow(Config).to receive(:nats_rpc)
          allow(Api::ResourceManager).to receive(:new)
        end

        it_acts_as_synchronous_message :stop
        it_acts_as_synchronous_message :cancel_task
        it_acts_as_synchronous_message :get_state
        it_acts_as_synchronous_message :list_disk
        it_acts_as_synchronous_message :prepare_network_change
        it_acts_as_synchronous_message :start
      end
    end


    describe 'ping <=> pong' do
      let(:stemcell) do
        Models::Stemcell.make(:cid => 'stemcell-id')
      end

      let(:network_settings) do
        { 'network_a' => { 'ip' => '1.2.3.4' } }
      end

      let(:vm_model) do
        cloud = instance_double('Bosh::Cloud')
        allow(Config).to receive(:cloud).and_return(cloud)
        env = {}
        deployment = Models::Deployment.make
        cloud_properties = { 'ram' => '2gb' }
        allow(cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
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
        AgentClient.with_defaults(vm_model.agent_id)
      end

      it 'should use vm credentials' do
        nats_rpc = double('nats_rpc')

        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
        Config.encryption = true

        allow(App).to receive_messages(instance: double('App Instance').as_null_object)

        handler = Bosh::Core::EncryptionHandler.new(vm_model.agent_id, vm_model.credentials)
        expect(nats_rpc).to receive(:send_request) do |*args, &blk|
          data = args[1]['encrypted_data']
          handler.decrypt(data) # decrypt to initiate session
          blk.call('encrypted_data' => handler.encrypt('value' => 'pong'))
        end

        expect(client.ping).to eq('pong')
      end
    end

    before do
      allow(Api::ResourceManager).to receive(:new)
      @nats_rpc = instance_double('Bosh::Director::NatsRpc')
      allow(Bosh::Director::Config).to receive(:nats_rpc).and_return(@nats_rpc)
    end

    let(:test_args) do
      ['arg 1', 2, { :test => 'blah' }]
    end

    let(:expected_rpc_args) do
      @expected_rpc_args = { protocol: Bosh::Director::AgentClient::PROTOCOL_VERSION, arguments: test_args, method: :baz }
    end

    it 'should send messages and return values' do
      response = { 'value' => 5 }

      expect(@nats_rpc).to receive(:send_request).
        with('foo.bar', expected_rpc_args).and_yield(response)

      client = AgentClient.new('foo', 'bar')
      expect(client.baz(*test_args)).to eq(5)
    end

    it 'should include the current protocol version in each request' do
      expect(@nats_rpc).to receive(:send_request).
        with(anything(), hash_including(protocol: Bosh::Director::AgentClient::PROTOCOL_VERSION)).
        and_yield({'value' => 'whatever'})

      client = AgentClient.new('foo', 'bar')
      client.baz(*test_args)
    end

    it 'should handle exceptions' do
      response = {
        'exception' => {
          'message' => 'test',
          'backtrace' => %w(a b c),
          'blobstore_id' => 'deadbeef'
        }
      }

      expect(@nats_rpc).to receive(:send_request).
        with('foo.bar', expected_rpc_args).and_yield(response)

      rm = double(Bosh::Director::Api::ResourceManager)
      expect(rm).to receive(:get_resource).with('deadbeef').and_return('an exception')
      expect(rm).to receive(:delete_resource).with('deadbeef')
      expect(Bosh::Director::Api::ResourceManager).to receive(:new).and_return(rm)

      client = AgentClient.new('foo', 'bar')
      expected_error_message = "test\na\nb\nc\nan exception"

      expect {
        client.baz(*test_args)
      }.to raise_exception(Bosh::Director::RpcRemoteException, expected_error_message)
    end

    describe 'timeouts/retries' do
      it 'should handle timeouts' do
        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', expected_rpc_args).and_return('req_id')
        expect(@nats_rpc).to receive(:cancel_request).with('req_id')

        client = AgentClient.new('foo', 'bar', timeout: 0.1)

        expect {
          client.baz(*test_args)
        }.to raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry only methods in the options list' do
        client_opts = {
          timeout: 0.1,
          retry_methods: { foo: 10 }
        }

        args = { method: :baz, arguments: [] }

        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', hash_including(args)).once.and_raise(Bosh::Director::RpcTimeout)

        client = AgentClient.new('foo', 'bar', client_opts)

        expect {
          client.baz
        }.to raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry methods' do
        args = { method: :baz, arguments: [] }

        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', hash_including(args)).exactly(2).times.and_raise(Bosh::Director::RpcTimeout)

        client_opts = {
          timeout: 0.1,
          retry_methods: { baz: 1 }
        }

        client = AgentClient.new('foo', 'bar', client_opts)

        expect {
          client.baz
        }.to raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry only timeout errors' do
        args = { method: :baz, arguments: [] }

        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', hash_including(args)).once.and_raise(RuntimeError.new('foo'))

        client_opts = {
          timeout: 0.1,
          retry_methods: { retry_method: 10 }
        }

        client = AgentClient.new('foo', 'bar', client_opts)

        expect {
          client.baz
        }.to raise_exception(RuntimeError, 'foo')
      end

      describe :wait_until_ready do
        let(:client) { AgentClient.new('foo', 'bar', timeout: 0.1) }

        it 'should wait for the agent to be ready' do
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          expect(client).to receive(:ping).and_return(true)

          client.wait_until_ready
        end

        it 'should wait for the agent if it is restarting' do
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcRemoteException, 'restarting agent')
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          expect(client).to receive(:ping).and_return(true)

          client.wait_until_ready
        end

        it 'should raise an exception if there is a remote exception' do
          expect(client).to receive(:ping).and_raise(Bosh::Director::RpcRemoteException, 'remote exception')

          expect { client.wait_until_ready }.to raise_error(Bosh::Director::RpcRemoteException)
        end
      end
    end

    describe 'encryption' do
      it 'should encrypt message' do
        credentials = Bosh::Core::EncryptionHandler.generate_credentials
        client_opts = { timeout: 0.1, :credentials => credentials }
        response = { 'value' => 5 }

        expect(@nats_rpc).to receive(:send_request) { |*args, &blk|
          expect(args[0]).to eq('foo.bar')
          request = args[1]
          data = request['encrypted_data']

          handler = Bosh::Core::EncryptionHandler.new('bar', credentials)

          message = handler.decrypt(data)
          expect(message['method']).to eq('baz')
          expect(message['arguments']).to eq([1, 2, 3])
          expect(message['sequence_number'].to_i).to be > Time.now.to_i
          expect(message['client_id']).to eq('bar')

          blk.call('encrypted_data' => handler.encrypt(response))
        }

        client = AgentClient.new('foo', 'bar', client_opts)
        expect(client.baz(1, 2, 3)).to eq(5)
      end
    end

    describe 'handling compilation log' do
      it 'should inject compile log into response' do
        response = {
          'value' => {
            'result' => {
              'compile_log_id' => 'cafe'
            }
          }
        }

        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', expected_rpc_args).and_yield(response)

        rm = instance_double('Bosh::Director::Api::ResourceManager')
        expect(rm).to receive(:get_resource).with('cafe').and_return('blob')
        expect(rm).to receive(:delete_resource).with('cafe')
        expect(Bosh::Director::Api::ResourceManager).to receive(:new).and_return(rm)

        client = AgentClient.new('foo', 'bar')
        value = client.baz(*test_args)
        expect(value['result']['compile_log']).to eq('blob')
      end
    end

    describe 'formatting RPC remote exceptions' do
      it 'supports old style (String)' do
        client = AgentClient.new('foo', 'bar')
        expect(client.format_exception('message string')).to eq('message string')
      end

      it 'supports new style (Hash)' do
        exception = {
          'message' => 'something happened',
          'backtrace' => ['in zbb.rb:35', 'in zbb.rb:26'],
          'blobstore_id' => 'deadbeef'
        }

        rm = instance_double('Bosh::Director::Api::ResourceManager')
        allow(Bosh::Director::Api::ResourceManager).to receive(:new).and_return(rm)
        expect(rm).to receive(:get_resource).with('deadbeef').
          and_return("Failed to compile: no such file 'zbb'")
        expect(rm).to receive(:delete_resource).with('deadbeef')

        expected_error = "something happened\nin zbb.rb:35\nin zbb.rb:26\nFailed to compile: no such file 'zbb'"

        client = AgentClient.new('foo', 'bar')
        expect(client.format_exception(exception)).to eq(expected_error)
      end
    end

    describe '#run_errand' do
      it 'sends a run errand message over nats and returns a task' do
        nats_rpc = instance_double('Bosh::Director::NatsRpc')
        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)

        client = AgentClient.new('fake-service-name', 'fake-client-id')

        args = double
        nats_rpc_response = {
          'value' => {
            'state' => 'running',
            'agent_task_id' => 'fake-task-id',
          }
        }

        expect(nats_rpc).to receive(:send_request).with(
          'fake-service-name.fake-client-id', hash_including(method: :run_errand, arguments: [args]))
          .and_yield(nats_rpc_response)

        expect(client.run_errand(args)).to eq({
          'state' => 'running',
          'agent_task_id' => 'fake-task-id',
        })
      end
    end

    describe '#wait_for_task' do
      let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc') }
      before { allow(Config).to receive(:nats_rpc).and_return(nats_rpc) }

      context 'when a block is passed' do
        let(:fake_block) { Proc.new {} }

        it 'calls the block while the task is running' do
          client = AgentClient.new('fake-service-name', 'fake-client-id')

          nats_rpc_response = {
            'value' => {
              'state' => 'running',
              'agent_task_id' => 'fake-task-id',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'state' => 'done',
              'agent_task_id' => 'fake-task-id'
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          expect(fake_block).to receive(:call).exactly(1).times

          client.wait_for_task('fake-task-id', &fake_block)
        end

        it 'sleeps for the default poll interval' do
          client = AgentClient.new('fake-service-name', 'fake-client-id')

          allow(fake_block).to receive(:call)

          nats_rpc_response = {
            'value' => {
              'state' => 'running',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'value' => 'fake-return-value',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          expect(client).to receive(:sleep).with(1.0)

          client.wait_for_task('fake-task-id', &fake_block)
        end

        it 'returns the task value' do
          client = AgentClient.new('fake-service-name', 'fake-client-id')

          nats_rpc_response = {
            'value' => {
              'state' => 'done',
              'value' => 'fake-return-value',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          expect(client.wait_for_task('fake-task-id', &fake_block)).to eq('fake-return-value')
        end
      end

      context 'when no block is passed' do
        it 'sleeps for the default poll interval and returns task value' do
          client = AgentClient.new('fake-service-name', 'fake-client-id')

          nats_rpc_response = {
            'value' => {
              'state' => 'running',
              'agent_task_id' => 'fake-task-id'
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'state' => 'done',
              'value' => 'fake-return-value',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']))
            .and_yield(nats_rpc_response)

          expect(client).to receive(:sleep).with(1.0)

          client.wait_for_task('fake-task-id')
        end
      end
    end
  end
end
