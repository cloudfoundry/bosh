require 'spec_helper'

describe Bosh::Agent::Handler do
  subject(:handler) { described_class.new }

  before(:each) do
    @nats = double('nats', publish: nil)
    EM.stub(:run).and_yield
    NATS.stub(:connect).and_return(@nats)

    Bosh::Agent::AlertProcessor.stub(:start)
    Bosh::Agent::Heartbeat.stub(:enable)
    Bosh::Agent::SyslogMonitor.stub(:start)

    Bosh::Agent::Config.process_alerts = true
    Bosh::Agent::Config.smtp_port = 55213
    Bosh::Agent::Config.smtp_user = 'user'
    Bosh::Agent::Config.smtp_password = 'pass'

    EM.stub(:next_tick).and_yield
  end

  let(:task_id) { 'my_task_id' }
  before { allow(handler).to receive(:generate_agent_task_id).and_return(task_id) }

  it 'should result in a value payload' do
    payload = handler.process(Bosh::Agent::Message::Ping, nil)
    payload.should == { :value => 'pong' }
  end

  it 'should attempt to start alert processor when handler starts' do
    Bosh::Agent::AlertProcessor.should_receive(:start).with('127.0.0.1', 55213, 'user', 'pass')

    handler.start
  end

  it 'should attempt to start syslog monitor when handler starts' do
    Bosh::Agent::SyslogMonitor.should_receive(:start).with(@nats, anything)

    handler.start
  end

  it 'should not start alert processor if alerts are disabled via config' do
    Bosh::Agent::Config.process_alerts = false
    Bosh::Agent::AlertProcessor.should_not_receive(:start)

    Bosh::Agent::Handler.new.start
  end

  it 'should not start syslog monitor if alerts are disabled via config' do
    Bosh::Agent::Config.process_alerts = false
    Bosh::Agent::SyslogMonitor.should_not_receive(:start)

    Bosh::Agent::Handler.new.start
  end

  it 'should result in an exception payload' do
    klazz = Class.new do
      def self.process(args)
        raise Bosh::Agent::MessageHandlerError, 'boo!'
      end
    end
    payload = handler.process(klazz, nil)
    payload.should have_key :exception
    exception = payload[:exception]
    exception.should have_key :message
    exception[:message].should == 'boo!'
  end

  it 'should process long running tasks' do
    handler.start

    klazz = Class.new do
      def self.process(args)
        'result'
      end

      def self.long_running?
        true
      end
    end

    SecureRandom.stub(uuid: 'my_task_id')

    @nats.should_receive(:publish).with('bogus_reply_to', JSON.generate(value: { state: 'running', agent_task_id: 'my_task_id' }))
    handler.process_long_running('bogus_reply_to', klazz, nil)

    @nats.should_receive(:publish).with('another_bogus_reply_to', JSON.generate(value: 'result'))
    handler.handle_get_task('another_bogus_reply_to', 'my_task_id')
  end

  describe 'get_task' do
    let(:processor) { double(:processor, process: 'result', done: false) }
    before { stub_const('Bosh::Agent::Message::LongRunningTask', processor) }

    let(:message) {
      JSON.generate(
        reply_to: 'test',
        method: 'get_task',
        arguments: [task_id]
      )
    }

    before { handler.start }

    context 'when the task_id is running' do
      before do
        allow(processor).to receive(:process) do
          handler.handle_message(message)
          'result'
        end
      end

      it 'returns running state' do
        expect(@nats).to receive(:publish).
                           with('test', JSON.generate(value: { state: 'running', agent_task_id: task_id }))
        handler.process_long_running('bogus_reply_to', processor, nil)
      end
    end

    context 'when the task_id has a result' do
      it 'returns the task result' do
        handler.process_long_running('bogus_reply_to', processor, nil)

        expect(@nats).to receive(:publish).with('test', JSON.generate(value: 'result'))
        handler.handle_message(message)
      end
    end

    context 'when agent does not have task_id' do
      it 'returns exception' do
        @nats.should_receive(:publish).with('test', JSON.generate(exception: 'unknown agent_task_id'))
        handler.handle_message(message)
      end
    end
  end

  describe 'cancel_task' do
    let(:processor) { double(:processor, cancel: nil) }
    before do
      stub_const('Bosh::Agent::Message::LongRunningTask', processor)
      allow(processor).to receive(:process) do
        handler.handle_message(message)
        'result'
      end
    end

    let(:message) {
      JSON.generate(
        reply_to: 'test',
        method: 'cancel_task',
        arguments: [task_id]
      )
    }

    before { handler.start }

    context 'when the task_id is running' do
      it 'cancels the processor' do
        expect(processor).to receive(:cancel).with(no_args)

        handler.process_long_running('bogus_reply_to', processor, nil)
      end

      it 'returns cancelled' do
        expect(@nats).to receive(:publish).with('test', JSON.generate(value: 'canceled'))

        handler.process_long_running('bogus_reply_to', processor, nil)
      end

      it 'removes the current long-running task' do
        allow(processor).to receive(:process) do
          handler.handle_message(message)
          handler.handle_message(JSON.generate(reply_to: 'test', method: 'get_task', arguments: [task_id]))
          'result'
        end

        # unknown because it's not stored as running anymore and has not yet completed when we send get_task
        expect(@nats).to receive(:publish).with('test', JSON.generate(exception: 'unknown agent_task_id'))

        handler.process_long_running('bogus_reply_to', processor, nil)
      end

      context 'when the processor does not support cancellation' do
        before { allow(processor).to receive(:respond_to?).with(:cancel).and_return(false) }

        it 'returns an exception' do
          expect(@nats).to receive(:publish).with('test', JSON.generate(exception: "could not cancel task #{task_id}"))

          handler.process_long_running('bogus_reply_to', processor, nil)
        end
      end
    end

    context 'when the task_id is not running' do
      it 'returns an exception' do
        allow(handler).to receive(:generate_agent_task_id).and_return('some-other-task-id')

        expect(@nats).to receive(:publish).with('test', JSON.generate(exception: 'unknown agent_task_id'))

        handler.process_long_running('bogus_reply_to', processor, nil)
      end
    end
  end

  it 'should support CamelCase message handler class names' do
    ::Bosh::Agent::Message::CamelCasedMessageHandler = Class.new do
      def self.process(args)
      end
    end
    Bosh::Agent::Handler.new.processors.keys.should include('camel_cased_message_handler')
  end

  it 'handle message should fail on broken json' do
    Bosh::Agent::Config.logger.should_receive(:info).with(/Message processors/)
    Bosh::Agent::Config.logger.should_receive(:info).with(/Yajl::ParseError/)

    Bosh::Agent::Handler.new.handle_message('}}}b0rked}}}json')
  end

  it 'should retry nats connection when it fails' do
    retries = Bosh::Agent::Handler::MAX_NATS_RETRIES
    NATS.stub(:connect).and_raise(NATS::ConnectError)
    handler.stub(:sleep)
    handler.should_receive(:sleep).exactly(retries).times
    handler.start
  end

  it 'should report unexpected errors then terminate its thread in 15 seconds' do
    klazz = Class.new do
      def self.process(args)
        raise 'How unexpected of you!'
      end
    end
    handler.should_receive(:kill_main_thread_in).once
    handler.instance_eval do
      @logger.should_receive(:error).with(
        /#<RuntimeError: How unexpected of you!/)
    end
    payload = handler.process(klazz, nil)
    payload[:exception].should match(/#<RuntimeError: How unexpected of you!/)
  end

  describe 'Encryption' do

    before(:each) do
      @credentials = Bosh::Core::EncryptionHandler.generate_credentials
      Bosh::Agent::Config.credentials = @credentials

      @handler = Bosh::Agent::Handler.new
      @handler.nats = @nats

      @encryption_handler = Bosh::Core::EncryptionHandler.new('client_id', @credentials)

      @cipher = Gibberish::AES.new(@credentials['crypt_key'])
    end

    it 'should decrypt message and encrypt response with credentials' do
      # The expectation uses a non-existent message handler to avoid the handler
      # to spawn a thread.
      @nats.should_receive(:publish).with('inbox.client_id',
                                          kind_of(String)
      ) { |*args|
        msg = @encryption_handler.decode(args[1])
        msg['session_id'].should == @encryption_handler.session_id

        decrypted_data = @encryption_handler.decrypt(msg['encrypted_data'])
        decrypted_data['exception'].should have_key('message')
        decrypted_data['exception']['message'].should match(/bogus_ping/)
      }

      encrypted_data = @encryption_handler.encrypt(
        'method' => 'bogus_ping', 'arguments' => []
      )

      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_data
        )
      )
    end

    it 'should handle decrypt failure' do
      @encryption_handler.encrypt('random' => 'stuff')

      @handler.stub(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::Core::EncryptionHandler::DecryptionError)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => 'junk'
        )
      )
    end

    it 'should handle session errors' do
      encrypted_data = @encryption_handler.encrypt(
        'method' => 'bogus_message', 'arguments' => []
      )

      @nats.should_receive(:publish).with('inbox.client_id',
                                          kind_of(String))

      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_data
        )
      )

      encrypted_data2 = @encryption_handler.encrypt(
        'method' => 'bogus_message', 'arguments' => []
      )

      message = @encryption_handler.decode(
        @cipher.decrypt(encrypted_data)
      )

      data = @encryption_handler.decode(message['json_data'])
      data['session_id'] = 'bosgus_session_id'

      json_data = @encryption_handler.encode(data)
      message['hmac'] = @encryption_handler.signature(json_data)
      message['json_data'] = json_data

      encrypted_bad_data = @cipher.encrypt(@encryption_handler.encode(message))

      @handler.stub(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::Core::EncryptionHandler::SessionError, /session_id mismatch/)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_bad_data
        )
      )
    end

    it 'should handle signature errors' do
      encrypted_data = @encryption_handler.encrypt(
        'method' => 'bogus_message', 'arguments' => []
      )
      message = @encryption_handler.decode(
        @cipher.decrypt(encrypted_data)
      )
      message['hmac'] = @encryption_handler.signature('some other data')

      encrypted_bad_data = @cipher.encrypt(@encryption_handler.encode(message))

      @handler.stub(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::Core::EncryptionHandler::SignatureError, /Expected hmac/)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_bad_data
        )
      )
    end

    it 'should handle sequence number errors' do
      encrypted_data = @encryption_handler.encrypt(
        'method' => 'bogus_message', 'arguments' => []
      )

      @nats.should_receive(:publish).with('inbox.client_id',
                                          kind_of(String))
      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_data
        )
      )

      @handler.stub(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::Core::EncryptionHandler::SequenceNumberError)
      }

      # Send it again
      @handler.handle_message(
        @encryption_handler.encode(
          'reply_to' => 'inbox.client_id',
          'session_id' => @encryption_handler.session_id,
          'encrypted_data' => encrypted_data
        )
      )
    end
  end

  it 'should raise a RemoteException when message > NATS_MAX_PAYLOAD' do
    payload = 'a' * (Bosh::Agent::Handler::NATS_MAX_PAYLOAD_SIZE + 1)
    @nats.should_receive(:publish).with('reply', '{"exception":{"message":"exception"}}')

    mock = double(Bosh::Agent::RemoteException)
    mock.stub(:to_hash).and_return(:exception => {:message => 'exception'})
    Bosh::Agent::RemoteException.should_receive(:new).and_return(mock)

    handler.start
    handler.publish('reply', payload)
  end

  describe 'prepare_network_change' do
    let(:udev_file) { '/etc/udev/rules.d/70-persistent-net.rules' }
    let(:settings_file) { Tempfile.new('test') }

    it 'should delete the settings file and restart the agent' do
      handler.start
      Bosh::Agent::Config.configure = true
      Bosh::Agent::Config.settings_file = settings_file

      EM.should_receive(:defer).and_yield
      @nats.should_receive(:publish).and_yield
      File.should_receive(:exist?).with(udev_file).and_return(false)
      File.should_receive(:delete).with(settings_file)
      handler.should_receive(:kill_main_thread_in).with(1)

      handler.handle_message(Yajl::Encoder.encode('method' => 'prepare_network_change',
                                                  'reply_to' => 'inbox.client_id',
                                                  'arguments' => []))

    end
  end
end
