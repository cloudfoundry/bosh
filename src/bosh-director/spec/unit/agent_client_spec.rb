require 'spec_helper'

module Bosh::Director
  describe AgentClient do
    before do
      RSpec.configure do |config|
        config.mock_with :rspec do |mocks|
          # Remove after fixing several specs that stub out private methods
          mocks.verify_partial_doubles = false
        end
      end
    end

    after do
      RSpec.configure do |config|
        config.mock_with :rspec do |mocks|
          # Remove after fixing several specs that stub out private methods
          mocks.verify_partial_doubles = true
        end
      end
    end

    let(:options) { {'logging' => true} }
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

    def self.it_acts_as_message_with_timeout(message_name)
      it 'waits for results with timeout' do
        expect(client).to receive(:send_message_with_timeout).exactly(1).times
        client.public_send(message_name, 'fake', 'args')
      end
    end

    context 'task is asynchronous' do
      describe 'it has agent_task_id' do
        subject(:client) { AgentClient.with_agent_id('fake-agent-id') }
        let(:task) do
          {
              'agent_task_id' => 'fake-agent_task_id',
              'state' => 'running',
              'value' => 'task value'
          }
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
          it_acts_as_asynchronous_message :stop
          it_acts_as_asynchronous_message :cancel_task
          it_acts_as_asynchronous_message :list_disk
          it_acts_as_asynchronous_message :associate_disks
          it_acts_as_asynchronous_message :start
        end

        describe 'update_settings' do
          it 'packages the certificates and disk associations into a map and sends to the agent' do
            expect(client).to receive(:send_message).with(
              :update_settings,
              {
              "trusted_certs" => "these are the certificates",
              'disk_associations' => [{'name' => 'zak', 'cid' => 'new-disk-cid'}]
              })
            allow(client).to receive(:get_task)
            client.update_settings("these are the certificates", [{'name' => 'zak', 'cid' => 'new-disk-cid'}])
          end

          it 'periodically polls the update settings task while it is running' do
            allow(client).to receive(:handle_message_with_retry).and_return task
            allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
            expect(client).to receive(:get_task).with('fake-agent_task_id')
            client.update_settings("these are the certificates", [{'name' => 'zak', 'cid' => 'new-disk-cid'}])
          end

          it 'is only a warning when the remote agent does not implement update_settings' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "unknown message update_settings")

            expect(Config.logger).to receive(:warn).with("Ignoring update_settings 'unknown message' error from the agent: #<Bosh::Director::RpcRemoteException: unknown message update_settings>")
            expect { client.update_settings("no certs", "no disks") }.to_not raise_error
          end

          it 'still raises an exception for other RPC failures' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, "random failure!")

            expect(client).to_not receive(:warning)
            expect { client.update_settings("no certs", "no disks") }.to raise_error
          end
        end

        describe 'cancel drain' do
          it 'should stop execution if task was canceled' do
            allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
            expect(client).to receive(:start_task).and_return task
            expect(client).to receive(:get_task_status).and_return task

            cancel_task = task.dup
            cancel_task['state'] = 'not running'
            expect(client).to receive(:cancel_task).and_return cancel_task

            task_cancelled = TaskCancelled.new(1)
            expect(Config).to receive(:job_cancelled?).and_raise(task_cancelled)

            expect{client.drain("fake", "args")}.to raise_error(task_cancelled)
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

        describe 'upload_blob' do
          it 'sends payload, payload_checksum, and blob_id to the agent' do
            expect(client).to receive(:send_message).with(:upload_blob, {
              'blob_id' => 'blob_id',
              'checksum' =>'payload_checksum',
              'payload' => 'base64_encoded_payload'
            })
            allow(client).to receive(:get_task)
            client.upload_blob('blob_id', 'payload_checksum', 'base64_encoded_payload')
          end

          it 'periodically polls the upload_blob task while it is running' do
            allow(client).to receive(:handle_message_with_retry).and_return task
            allow(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL)
            expect(client).to receive(:get_task).with('fake-agent_task_id')
            client.upload_blob('blob_id', 'payload_checksum', 'base64_encoded_payload')
          end

          context 'when the agent does not implement upload_blob' do
            it 'raises an unsupported action exception' do
              allow(client).to receive(:handle_method).and_raise(RpcRemoteException, 'unknown message')

              expect {
                client.upload_blob('blob_id', 'payload_checksum', 'base64_encoded_payload')
              }.to raise_error(Bosh::Director::AgentUnsupportedAction, 'Unsupported action: upload_blob')
            end
          end

          context 'when the agent returns an error "Opening blob store file"' do
            it 'raises an AgentUploadBlobUnableToOpenFile exception' do
              allow(client).to receive(:handle_method).and_raise(RpcRemoteException, 'Opening blob store file: open \var\vcap\data\blobs/adaff25a-df7b-4f2f-86d5-74fd50fc8c06: The system cannot find the path specified.')

              expect {
                client.upload_blob('blob_id', 'payload_checksum', 'base64_encoded_payload')
              }.to raise_error(Bosh::Director::AgentUploadBlobUnableToOpenFile, "'Upload blob' action: failed to open blob")
            end
          end

          it 'raises an exception for other RPC failures' do
            allow(client).to receive(:handle_method).and_raise(RpcRemoteException, 'failure has been found')

            expect(client).to_not receive(:warning)
            expect { client.upload_blob('blob_id', 'payload_checksum', 'base64_encoded_payload') }.to raise_error
          end
        end

        context 'task can time out' do
          it_acts_as_message_with_timeout :stop
        end
      end
    end

    context 'task is fired and forgotten' do
      describe 'delete_arp_entries' do
        subject(:client) { AgentClient.with_agent_id('fake-agent-id') }
        let(:task) do
          {
            'agent_task_id' => 'fake-agent_task_id',
            'state' => 'running',
            'value' => 'task value'
          }
        end
        let(:nats_rpc) { instance_double(Bosh::Director::NatsRpc, cancel_request: nil) }
        let(:request_id) { 'my-request' }

        before do
          allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
          allow(Api::ResourceManager).to receive(:new)
        end

        it 'sends delete_arp_entries to the agent' do
          expect(client).to receive(:send_nats_request_quietly) do |message_name, args|
            expect(message_name).to eq(:delete_arp_entries)
            expect(args).to eq([ips: ['10.10.10.1', '10.10.10.2']])
          end

          client.delete_arp_entries(ips: ['10.10.10.1', '10.10.10.2'])
        end

        it 'cancels the request on the NatsRPC to avoid memory leaks' do
          allow(client).to receive(:send_nats_request_quietly).and_return(request_id)
          expect(nats_rpc).to receive(:cancel_request).with(request_id)

          client.delete_arp_entries(ips: ['10.10.10.1', '10.10.10.2'])
        end

        it 'does not raise an exception for failures' do
          allow(client).to receive(:send_nats_request_quietly).and_raise(RpcRemoteException, 'random failure!')

          expect(Config.logger).to receive(:warn).with("Ignoring 'random failure!' error from the agent: #<Bosh::Director::RpcRemoteException: random failure!>. Received while trying to run: delete_arp_entries on client: 'fake-agent-id'")
          expect { client.delete_arp_entries(ips: ['10.10.10.1', '10.10.10.2']) }.to_not raise_error
        end
      end
    end

    describe '#sync_dns' do
      subject(:client) {AgentClient.with_agent_id('fake-agent-id', timeout: 0.1)}
      let(:nats_rpc) {instance_double(Bosh::Director::NatsRpc)}

      before do
        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
        allow(Api::ResourceManager).to receive(:new)
      end

      it 'sends sync_dns to the agent' do
        expect(client).to receive(:send_nats_request_quietly) do |message_name, args|
          expect(message_name).to eq(:sync_dns)
          expect(args).to eq([blobstore_id: 'fake-blob-id', sha1: 'fakesha1'])
        end
        client.sync_dns(blobstore_id: 'fake-blob-id', sha1: 'fakesha1')
      end

      it 'sends sync_dns to the agent with version parameter' do
        expect(client).to receive(:send_nats_request_quietly) do |message_name, args|
          expect(message_name).to eq(:sync_dns)
          expect(args).to eq([blobstore_id: 'fake-blob-id', sha1: 'fakesha1', version: 1])
        end
        client.sync_dns(blobstore_id: 'fake-blob-id', sha1: 'fakesha1', version: 1)
      end

      it 'does not log sync_dns calls' do
        expect(nats_rpc).to receive(:send_request).with(
          'agent.fake-agent-id',
          'fake-agent-id',
          hash_including(:method=>:sync_dns),
          {'logging' => false}
        )
        client.sync_dns(blobstore_id: 'fake-blob-id', sha1: 'fakesha1', version: 1)
      end
    end

    describe '#cancel_sync_dns' do
      subject(:client) { AgentClient.with_agent_id('fake-agent-id', timeout: 0.1) }
      let(:nats_rpc) { instance_double(Bosh::Director::NatsRpc) }

      before do
        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
        allow(Api::ResourceManager).to receive(:new)
      end

      it 'cancels the specified nats rpc request' do
        expect(nats_rpc).to receive(:cancel_request).with('some-id')

        client.cancel_sync_dns('some-id')
      end
    end

    context 'task is synchronous' do
      describe 'it does not have agent_task_id' do
        subject(:client) { AgentClient.with_agent_id('fake-agent-id') }

        before do
          allow(Config).to receive(:nats_rpc)
          allow(Api::ResourceManager).to receive(:new)
        end

        it_acts_as_synchronous_message :stop
        it_acts_as_synchronous_message :cancel_task
        it_acts_as_synchronous_message :get_state
        it_acts_as_synchronous_message :list_disk
        it_acts_as_synchronous_message :start
        it_acts_as_synchronous_message :info
      end
    end

    describe '#info' do
      subject(:client) { AgentClient.with_agent_id('fake-agent-id') }

      it 'is returns api version 0 if the info endpoint is not implemented' do
        allow(client).to receive(:send_message).and_raise(RpcRemoteException, "unknown message info")

        expect(Config.logger).to receive(:warn).with("Ignoring info 'unknown message' error from the agent: #<Bosh::Director::RpcRemoteException: unknown message info>")
        expect(client.info).to eq({ 'api_version' => 0 })
      end
    end

    describe 'ping <=> pong' do
      let(:stemcell) do
        Models::Stemcell.make(:cid => 'stemcell-id')
      end

      let(:network_settings) do
        { 'network_a' => { 'ip' => '1.2.3.4' } }
      end

      subject(:client) do
        AgentClient.with_agent_id('fake-agent-id')
      end

      it 'should returns pong when pinged' do
        nats_rpc = double('nats_rpc')

        allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
        allow(App).to receive_messages(instance: double('App Instance').as_null_object)

        expect(nats_rpc).to receive(:send_request) do |*args, &blk|
          blk.call({'value' => 'pong'})
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
        with('foo.bar', 'bar', expected_rpc_args, options).and_yield(response)

      client = AgentClient.new('foo', 'bar')
      expect(client.baz(*test_args)).to eq(5)
    end

    it 'should include the current protocol version in each request' do
      expect(@nats_rpc).to receive(:send_request).
        with(anything(), 'bar', hash_including(protocol: Bosh::Director::AgentClient::PROTOCOL_VERSION), options).
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
        with('foo.bar', 'bar', expected_rpc_args, options).and_yield(response)

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
          with('foo.bar', 'bar', expected_rpc_args, options).and_return('req_id')
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
          with('foo.bar', 'bar', hash_including(args), options).once.and_raise(Bosh::Director::RpcTimeout)

        client = AgentClient.new('foo', 'bar', client_opts)

        expect {
          client.baz
        }.to raise_exception(Bosh::Director::RpcTimeout)
      end

      it 'should retry methods' do
        args = { method: :baz, arguments: [] }

        expect(@nats_rpc).to receive(:send_request).
          with('foo.bar', 'bar', hash_including(args), options).exactly(2).times.and_raise(Bosh::Director::RpcTimeout)

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
          with('foo.bar', 'bar', hash_including(args), options).once.and_raise(RuntimeError.new('foo'))

        client_opts = {
          timeout: 0.1,
          retry_methods: { retry_method: 10 }
        }

        client = AgentClient.new('foo', 'bar', client_opts)

        expect {
          client.baz
        }.to raise_exception(RuntimeError, 'foo')
      end

      it 'should cancel even if not timeout' do
        args = {method: :get_state, arguments: []}

        expect(@nats_rpc).to receive(:send_request).
          with('get_state.bar', 'bar', hash_including(args), options).once.and_return({})

        allow(@nats_rpc).to receive(:cancel_request)

        client_opts = {
          timeout: 0.1,
          retry_methods: {retry_method: 10}
        }
        client = AgentClient.new('get_state', 'bar', client_opts)

        task_id = 1
        task = Models::Task.make(:id => task_id, :state => 'cancelling')
        job = Jobs::BaseJob.new()
        job.task_id = task_id
        Config.instance_variable_set(:@current_job, job)

        expect {
          client.get_state { Config.job_cancelled? }
        }.to raise_exception(TaskCancelled)
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

        it 'should raise an exception if task was cancelled' do
          testjob_class = Class.new(Jobs::BaseJob) do
            define_method :perform do
              'foo'
            end
          end
          task_id = 1
          tasks_dir = Dir.mktmpdir
          allow(Config).to receive(:runtime).and_return({'instance' => 'name/id', 'ip' => '127.0.127.0'})
          allow(Config).to receive(:base_dir).and_return(tasks_dir)
          allow(Config).to receive(:cloud_options).and_return({})
          task = Models::Task.make(:id => task_id, :state => 'cancelling')
          testjob_class.perform(task_id, 'workername1')
          expect { client.wait_until_ready }.to raise_error(Bosh::Director::TaskCancelled)
        end
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
          with('foo.bar', 'bar', expected_rpc_args, options).and_yield(response)

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
          'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :run_errand, arguments: [args]), options)
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
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'state' => 'done',
              'agent_task_id' => 'fake-task-id'
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
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
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'value' => 'fake-return-value',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
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
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
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
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
            .and_yield(nats_rpc_response)

          nats_rpc_response = {
            'value' => {
              'state' => 'done',
              'value' => 'fake-return-value',
            }
          }

          expect(nats_rpc).to receive(:send_request).once.with(
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
            .and_yield(nats_rpc_response)

          expect(client).to receive(:sleep).with(1.0)

          client.wait_for_task('fake-task-id')
        end
      end

      context 'when timeout is passed' do
        let(:fake_timeout_ticks) { 3 }

        it 'uses the timeout if one is passed' do
          client = AgentClient.new('fake-service-name', 'fake-client-id')
          timeout = Timeout.new(fake_timeout_ticks)

          nats_rpc_response = {
            'value' => {
              'state' => 'running',
              'value' => 'fake-return-value',
            }
          }

          allow(nats_rpc).to receive(:send_request).with(
            'fake-service-name.fake-client-id', 'fake-client-id', hash_including(method: :get_task, arguments: ['fake-task-id']), options)
            .and_yield(nats_rpc_response)

          expect(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL).exactly(fake_timeout_ticks).times
          expect(timeout).to receive(:timed_out?).exactly(fake_timeout_ticks).times.and_return(false)
          expect(timeout).to receive(:timed_out?).and_return(true)
          expect(client.wait_for_task('fake-task-id', timeout)).to eq('fake-return-value')
        end
      end
    end

    describe '#stop' do
      let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc') }
      let(:fake_timeout_ticks) { 3 }

      before { allow(Config).to receive(:nats_rpc).and_return(nats_rpc) }

      it 'should timeout and continue on after 5 minutes' do
        handle_method_response = {
          'agent_task_id' => 'fake-task-id',
          'value' => 'fake-return-value',
          'state' => 'running',
        }

        timeout = Timeout.new(fake_timeout_ticks)

        allow(Timeout).to receive(:new).and_return(timeout)
        client = AgentClient.new('fake-service-name', 'fake-client-id')

        expect(client).to receive(:handle_method).with(:stop, []).once.and_return(handle_method_response)
        expect(client).to receive(:handle_method).with(:get_task, ['fake-task-id']).exactly(fake_timeout_ticks + 1).times.and_return(handle_method_response)

        expect(client).to receive(:sleep).with(AgentClient::DEFAULT_POLL_INTERVAL).exactly(fake_timeout_ticks).times
        expect(timeout).to receive(:timed_out?).exactly(fake_timeout_ticks).times.and_return(false)
        expect(timeout).to receive(:timed_out?).and_return(true)

        client.stop
      end

      it 'should suppress timeout errors received from the agent' do
        allow(Timeout).to receive(:new).and_return(Timeout.new(fake_timeout_ticks))

        client = AgentClient.new('fake-service-name', 'fake-client-id')

        expect(Config.logger).to receive(:warn).with("Ignoring stop timeout error from the agent: #<Bosh::Director::RpcRemoteException: Timed out waiting for service 'foo'.>")

        expect(client).to receive(:handle_method).with(:stop, []).once.and_return({ 'agent_task_id' => 'fake-task-id' })
        expect(client).to receive(:handle_method).and_raise(RpcRemoteException, "Timed out waiting for service 'foo'.")

        client.stop
      end
    end
  end
end
