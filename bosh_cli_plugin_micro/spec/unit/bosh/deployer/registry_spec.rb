require 'spec_helper'

require 'bosh/deployer/registry'
require 'yaml'

module Bosh::Deployer
  describe Registry do
    subject { described_class.new(endpoint, cloud_plugin, cloud_properties, state, logger) }

    let(:endpoint) { 'http://fake-user:fake-pass@fake.example.com:1234' }
    let(:cloud_plugin) { 'fake-plugin-name' }
    let(:deployments) { {} }
    let(:state) { instance_double('Bosh::Deployer::InstanceManager', deployments: deployments) }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }
    let(:cloud_properties) { 'fake-properties' }
    let(:http_client) { instance_double(HTTPClient, head: nil) }
    let(:db) { instance_double('Sequel::SQLite::Database') }

    before do
      allow(ENV).to receive(:to_hash).and_return('PATH' => '/bin')
      allow(File).to receive(:exist?).with('/bin/bosh-registry').and_return(true)
      allow(Process).to receive(:waitpid2).and_return(nil)
      allow(Process).to receive(:spawn).and_return('fake-pid')
      allow(Kernel).to receive(:sleep)
      allow(Bosh::Common).to receive(:retryable).and_yield
      allow(HTTPClient).to receive(:new).and_return(http_client)
      allow(Sequel).to receive(:connect).and_yield(db)
      allow(db).to receive(:create_table)
      allow(db).to receive(:[]).and_return([])
    end

    let(:db_tempfile) { instance_double('Tempfile', path: 'fake-db-path', unlink: nil) }
    let(:config_tmpfile) { instance_double('Tempfile', path: 'fake-config-path') }
    before do
      allow(Tempfile).to receive(:new).and_return(db_tempfile, config_tmpfile)
      allow(config_tmpfile).to receive(:write)
      allow(config_tmpfile).to receive(:close)
      allow(config_tmpfile).to receive(:unlink)
    end

    describe '#start' do
      context 'when bosh-registry command is not found' do
        it 'raises' do
          allow(File).to receive(:exist?).with('/bin/bosh-registry').and_return(false)

          expect { subject.start }.to raise_error(/bosh-registry command not found/)
        end
      end

      it 'writes out a configuration file for bosh-registry' do
        expected_hash = {
          'logfile' => './bosh-registry.log',
          'http' => {
            'port' => 1234,
            'user' => 'fake-user',
            'password' => 'fake-pass',
          },
          'db' => {
            'adapter' => 'sqlite',
            'database' => 'fake-db-path',
          },
          'cloud' => {
            'plugin' => 'fake-plugin-name',
            'fake-plugin-name' => cloud_properties,
          },
        }
        expected_yaml = YAML.dump(expected_hash)

        expect(config_tmpfile).to receive(:write).with(expected_yaml).ordered
        expect(config_tmpfile).to receive(:close).ordered

        subject.start
      end

      it 'runs migrations registry database' do
        subject.start
        expect(db).to have_received(:create_table).with(:registry_instances)
        expect(Sequel).to have_received(:connect)
                          .with('adapter' => 'sqlite', 'database' => 'fake-db-path')
      end

      context 'with previous deployments' do
        let(:deployments) { { 'registry_instances' => fake_registry_instances } }
        let(:fake_registry_instances) { double }

        it 'updates the databse with the previous deployments' do
          fake_instances_table = instance_double('Sequel::Dataset', insert_multiple: nil)
          allow(db).to receive(:[]).with(:registry_instances).and_return(fake_instances_table)

          subject.start

          expect(fake_instances_table).to have_received(:insert_multiple)
                                          .with(fake_registry_instances)
        end

      end

      it 'spawns the registry' do
        subject.start
        expect(Process).to have_received(:spawn).with('bosh-registry -c fake-config-path')
      end

      it 'waits for the registry to spawn' do
        allow(Process).to receive(:waitpid2).with('fake-pid', Process::WNOHANG).and_return(nil)

        subject.start
      end

      context 'when registry exits before 5 waits' do
        it 'raises' do
          allow(Process).to receive(:spawn).and_return('fake-pid')

          status = instance_double('Process::Status', exitstatus: 5)
          allow(Process).to receive(:waitpid2).with('fake-pid', Process::WNOHANG)
                            .and_return(nil, nil, nil, nil, ['fake-pid', status])

          expect {
            subject.start
          }.to raise_error(/failed, exit status=5/)
        end
      end

      class FakeRetryable
        attr_reader :block, :options, :callback

        def initialize(callback)
          @callback = callback
        end

        def retryable(options = {})
          @options = options
          yield
          callback.call
        end
      end

      it 'waits for the registry to be listening on a port' do
        allow(Process).to receive(:waitpid).and_return(nil)

        retryable_callback = proc do
          expect(http_client).to have_received(:head).with('http://127.0.0.1:1234')
        end

        fake_retryable = FakeRetryable.new(retryable_callback)
        stub_const('Bosh::Common', fake_retryable)

        subject.start

        expect(fake_retryable.options).to eq(
                                            on: Registry::RETRYABLE_HTTP_EXCEPTIONS,
                                            sleep: 0.5,
                                            tries: 300,
                                          )
      end

      context 'when the registry fails to listen on a port within the timeout' do
        it 'raises' do
          allow(Bosh::Common).to receive(:retryable).and_raise(Bosh::Common::RetryCountExceeded.new)

          expect {
            subject.start
          }.to raise_error(/Cannot access bosh-registry: /)
        end
      end

      describe 'cleanup' do
        context 'when the registry starts successfully' do
          it 'removes config file' do
            subject.start
            expect(config_tmpfile).to have_received(:unlink)
          end
        end
        context 'when there is a problem starting the registry' do
          it 'removes config file' do
            allow(Process).to receive(:spawn).and_raise('oops')

            expect { subject.start }.to raise_error(/oops/)

            expect(config_tmpfile).to have_received(:unlink)
          end
        end
      end
    end

    describe '#stop' do
      before { allow(Process).to receive(:kill) }

      context 'when the registry has been started' do
        before { subject.start }

        it 'attempts to kill the registry process and waits for it to exit' do
          expect(Process).to receive(:kill).with('INT', 'fake-pid').ordered
          allow(Process).to receive(:waitpid2).with('fake-pid').ordered

          subject.stop
        end

        context 'when the registry process has already exited' do
          it 'does not blow up' do
            allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

            expect { subject.stop }.to_not raise_error
          end
        end

        it 'saves the registry instances to deployments' do
          subject.stop
          expect(deployments['registry_instances']).to eq([])
        end

        context 'when reading database succeeds' do
          it 'removes the registry database' do
            subject.stop
            expect(db_tempfile).to have_received(:unlink)
          end
        end

        context 'when reading database fails' do
          it 'removes the registry database' do
            allow(db).to receive(:[]).and_raise('db error')
            expect { subject.stop }.to raise_error(/db error/)
            expect(db_tempfile).to have_received(:unlink)
          end
        end
      end

      context 'when stop is called before start' do
        it 'does not try to kill anything' do
          subject.stop
          expect(Process).to_not have_received(:kill)
        end

        it 'does not record registry_instances' do
          subject.stop
          expect(Sequel).to_not have_received(:connect)
        end
      end
    end
  end
end
