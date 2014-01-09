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
        instance_double('Bosh::Director::Models::Vm', credentials: nil)
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
        cloud = instance_double('Bosh::Cloud')
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

    before do
      Api::ResourceManager.stub(:new)
      @nats_rpc = instance_double('Bosh::Director::NatsRpc')
      Bosh::Director::Config.stub(:nats_rpc).and_return(@nats_rpc)
    end

    let(:test_args) do
      ['arg 1', 2, { :test => 'blah' }]
    end

    let(:test_rpc_args) do
      @test_rpc_args = { arguments: test_args, method: :baz }
    end

    def make(*args)
      AgentClient.new(*args)
    end

    it 'should send messages and return values' do
      response = { 'value' => 5 }

      @nats_rpc.should_receive(:send_request).
        with('foo.bar', test_rpc_args).and_yield(response)

      client = AgentClient.new('foo', 'bar')
      client.baz(*test_args).should == 5
    end

    it 'should handle exceptions' do
      response = {
        'exception' => {
          'message' => 'test',
          'backtrace' => %w(a b c),
          'blobstore_id' => 'deadbeef'
        }
      }

      @nats_rpc.should_receive(:send_request).
        with('foo.bar', test_rpc_args).and_yield(response)

      rm = double(Bosh::Director::Api::ResourceManager)
      rm.should_receive(:get_resource).with('deadbeef').and_return('an exception')
      rm.should_receive(:delete_resource).with('deadbeef')
      Bosh::Director::Api::ResourceManager.should_receive(:new).and_return(rm)

      client = make('foo', 'bar')
      expected_error_message = "test\na\nb\nc\nan exception"

      lambda {
        client.baz(*test_args)
      }.should raise_exception(Bosh::Director::RpcRemoteException, expected_error_message)
    end

    describe 'timeouts/retries' do
      it 'should handle timeouts' do
        @nats_rpc.should_receive(:send_request).
          with('foo.bar', test_rpc_args).and_return('req_id')
        @nats_rpc.should_receive(:cancel_request).with('req_id')

        client = make('foo', 'bar', timeout: 0.1)

        lambda {
          client.baz(*test_args)
        }.should raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry only methods in the options list' do
        client_opts = {
          timeout: 0.1,
          retry_methods: { foo: 10 }
        }

        args = { method: :baz, arguments: [] }

        @nats_rpc.should_receive(:send_request).
          with('foo.bar', args).once.and_raise(Bosh::Director::RpcTimeout)

        client = make('foo', 'bar', client_opts)

        lambda {
          client.baz
        }.should raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry methods' do
        args = { method: :baz, arguments: [] }

        @nats_rpc.should_receive(:send_request).
          with('foo.bar', args).exactly(2).times.and_raise(Bosh::Director::RpcTimeout)

        client_opts = {
          timeout: 0.1,
          retry_methods: { baz: 1 }
        }

        client = make('foo', 'bar', client_opts)

        lambda {
          client.baz
        }.should raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry only timeout errors' do
        args = { method: :baz, arguments: [] }

        @nats_rpc.should_receive(:send_request).
          with('foo.bar', args).once.and_raise(RuntimeError.new('foo'))

        client_opts = {
          timeout: 0.1,
          retry_methods: { retry_method: 10 }
        }

        client = make('foo', 'bar', client_opts)

        lambda {
          client.baz
        }.should raise_exception(RuntimeError, 'foo')
      end

      describe :wait_until_ready do
        let(:client) { make('foo', 'bar', timeout: 0.1) }

        it 'should wait for the agent to be ready' do
          client.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          client.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          client.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          client.should_receive(:ping).and_return(true)

          client.wait_until_ready
        end

        it 'should wait for the agent if it is restarting' do
          client.should_receive(:ping).and_raise(Bosh::Director::RpcRemoteException, 'restarting agent')
          client.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
          client.should_receive(:ping).and_return(true)

          client.wait_until_ready
        end

        it 'should raise an exception if there is a remote exception' do
          client.should_receive(:ping).and_raise(Bosh::Director::RpcRemoteException, 'remote exception')

          expect { client.wait_until_ready }.to raise_error(Bosh::Director::RpcRemoteException)
        end
      end
    end


    describe 'encryption' do
      it 'should encrypt message' do
        credentials = Bosh::Core::EncryptionHandler.generate_credentials
        client_opts = { timeout: 0.1, :credentials => credentials }
        response = { 'value' => 5 }

        @nats_rpc.should_receive(:send_request) { |*args, &blk|
          args[0].should == 'foo.bar'
          request = args[1]
          data = request['encrypted_data']

          handler = Bosh::Core::EncryptionHandler.new('bar', credentials)

          message = handler.decrypt(data)
          message['method'].should == 'baz'
          message['arguments'].should == [1, 2, 3]
          message['sequence_number'].to_i.should > Time.now.to_i
          message['client_id'].should == 'bar'

          blk.call('encrypted_data' => handler.encrypt(response))
        }

        client = make('foo', 'bar', client_opts)
        client.baz(1, 2, 3).should == 5
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

        @nats_rpc.should_receive(:send_request).
          with('foo.bar', test_rpc_args).and_yield(response)

        rm = instance_double('Bosh::Director::Api::ResourceManager')
        rm.should_receive(:get_resource).with('cafe').and_return('blob')
        rm.should_receive(:delete_resource).with('cafe')
        Bosh::Director::Api::ResourceManager.should_receive(:new).and_return(rm)

        client = make('foo', 'bar')
        value = client.baz(*test_args)
        value['result']['compile_log'].should == 'blob'
      end
    end

    describe 'formatting RPC remote exceptions' do
      it 'supports old style (String)' do
        client = make('foo', 'bar')
        client.format_exception('message string').should == 'message string'
      end

      it 'supports new style (Hash)' do
        exception = {
          'message' => 'something happened',
          'backtrace' => ['in zbb.rb:35', 'in zbb.rb:26'],
          'blobstore_id' => 'deadbeef'
        }

        rm = instance_double('Bosh::Director::Api::ResourceManager')
        Bosh::Director::Api::ResourceManager.stub(:new).and_return(rm)
        rm.should_receive(:get_resource).with('deadbeef').
          and_return("Failed to compile: no such file 'zbb'")
        rm.should_receive(:delete_resource).with('deadbeef')

        expected_error = "something happened\nin zbb.rb:35\nin zbb.rb:26\nFailed to compile: no such file 'zbb'"

        client = make('foo', 'bar')
        client.format_exception(exception).should == expected_error
      end
    end
  end
end
