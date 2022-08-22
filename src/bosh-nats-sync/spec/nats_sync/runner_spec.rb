require 'spec_helper'

describe NATSSync::Runner do
  subject { NATSSync::Runner.new(sample_config) }
  let(:user_sync_class) { class_double('NATSSync::UsersSync').as_stubbed_const }
  let(:user_sync_instance) { instance_double(NATSSync::UsersSync) }

  before do
    allow(NATSSync).to receive(:logger).and_return(logger)
    allow(logger).to receive :info
  end

  let(:logger) { spy('Logger') }

  describe 'when the runner is created with the sample config file' do
    let(:director_config) do
      { 'url' => 'http://127.0.0.1:25555', 'user' => 'admin', 'password' => 'admin', 'client_id' => 'client_id',
        'client_secret' => 'client_secret', 'ca_cert' => 'ca_cert',
        'director_subject_file' => '/var/vcap/data/nats/director-subject',
        'hm_subject_file' => '/var/vcap/data/nats/hm-subject' }
    end

    let(:file_path) { '/var/vcap/data/nats/auth.json' }
    before do
      allow(user_sync_instance).to receive(:execute_users_sync)
      allow(user_sync_class).to receive(:new).and_return(user_sync_instance)
      Thread.new do
        subject.run
      end
      sleep(2)
    end

    it 'should start UsersSync.execute_nats_sync function with the same parameters defined in the file' do
      expect(user_sync_class).to have_received(:new).with(file_path, director_config)
      expect(user_sync_instance).to have_received(:execute_users_sync)
    end

    it 'should log when starting' do
      expect(logger).to have_received(:info).with('Nats Sync starting...')
    end

    after do
      subject.stop
    end
  end

  describe 'exception handling' do
    before do
      error = StandardError.new('EM event loop exception')
      error.set_backtrace(['backtrace'])
      allow(EM).to receive(:stop_event_loop)

      allow(user_sync_instance).to receive(:execute_users_sync).and_raise(error)

      allow(user_sync_class).to receive(:new).and_return(user_sync_instance)
      Thread.new do
        subject.run
      end
      sleep(2)
    end

    context 'when EM loop error occurs' do
      it 'stops the EM loop and logs the error' do
        expect(EM).to have_received(:stop_event_loop)
        expect(logger).to have_received(:fatal).with('EM event loop exception')
        expect(logger).to have_received(:fatal).with('backtrace')
      end
    end
  end

  after do
    subject.stop
  end
end
