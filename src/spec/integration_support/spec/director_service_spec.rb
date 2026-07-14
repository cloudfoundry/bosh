require 'spec_helper'
require 'integration_support/director_service'
require 'integration_support/shell_command_builder'

module IntegrationSupport
  describe DirectorService do
    let(:logger) { double(Logging::Logger).as_null_object }
    let(:db_helper) { double('db_helper') }
    let(:config) { double('config').as_null_object }
    let(:director_tmp_path) { Dir.mktmpdir }

    subject(:service) do
      described_class.new(
        options: {
          db_helper: db_helper,
          director_tmp_path: director_tmp_path,
          director_config: '/dev/null',
          base_log_path: '/dev/null',
          audit_log_path: '/dev/null',
          director_port: 25_555,
        },
        command_builder_class: ShellCommandBuilder,
        logger: logger,
      )
    end

    before do
      allow(service).to receive(:write_config)
      allow(service).to receive(:migrate_database)
      allow(service).to receive(:reset)
      allow(service).to receive(:start_workers)
      allow(Kernel).to receive(:system)
      # Stub the director process and connector so no real process is started
      allow_any_instance_of(Service).to receive(:start)
      allow_any_instance_of(HTTPEndpointConnector).to receive(:try_to_connect)
    end
    after { FileUtils.rm_rf(director_tmp_path) }

    describe '#start — @migrated guard' do
      it 'runs migrations on the first start' do
        service.start(config)
        expect(service).to have_received(:migrate_database).once
      end

      it 'skips migrations on subsequent starts' do
        service.start(config)
        service.start(config)
        service.start(config)
        expect(service).to have_received(:migrate_database).once
      end

      it 'retries migration when a previous attempt raised an error' do
        call_count = 0
        allow(service).to receive(:migrate_database) do
          call_count += 1
          raise 'migration failed' if call_count == 1
        end

        expect { service.start(config) }.to raise_error('migration failed')
        service.start(config)
        expect(service).to have_received(:migrate_database).twice
      end
    end
  end
end
