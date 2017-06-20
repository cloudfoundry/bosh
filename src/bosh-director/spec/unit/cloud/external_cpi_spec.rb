require 'spec_helper'
require 'fakefs/spec_helpers'

describe Bosh::Clouds::ExternalCpi do
  include FakeFS::SpecHelpers

  subject(:external_cpi) { described_class.new('/path/to/fake-cpi/bin/cpi', 'fake-director-uuid') }

  def self.it_calls_cpi_method(method, *arguments)
    define_method(:call_cpi_method) { external_cpi.public_send(method, *arguments) }

    before { allow(File).to receive(:executable?).with('/path/to/fake-cpi/bin/cpi').and_return(true) }

    let (:method) {method}
    let(:cpi_response) { JSON.dump(result: nil, error: nil, log: '') }

    before { stub_const('Bosh::Clouds::Config', config) }
    let(:config) { double('Bosh::Clouds::Config', logger: double(:logger, debug: nil), cpi_task_log: cpi_log_path) }
    let(:cpi_log_path) { '/var/vcap/task/5/cpi' }

    before { FileUtils.mkdir_p('/var/vcap/task/5') }

    before { allow(Open3).to receive(:capture3).and_return([cpi_response, 'fake-stderr-data', exit_status]) }
    before { allow(Random).to receive(:rand).and_return('fake-request-id') }
    let(:exit_status) { instance_double('Process::Status', exitstatus: 0) }

    it 'calls cpi binary with correct arguments' do
      stub_const('ENV', 'TMPDIR' => '/some/tmp')

      expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
      expected_cmd = '/path/to/fake-cpi/bin/cpi'
      expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":{"director_uuid":"fake-director-uuid","request_id":"fake-request-id"}})

      expect(Open3).to receive(:capture3).with(expected_env, expected_cmd, stdin_data: expected_stdin, unsetenv_others: true)
      call_cpi_method
    end

    context 'if properties from cpi config are given' do
      let(:director_uuid) {'fake-director-uuid'}
      let(:request_id) {'fake-request-id'}
      let(:cpi_config_properties) { {'key1' => {'nestedkey1' => 'nestedvalue1'}, 'key2' => 'value2'} }
      let(:external_cpi) { described_class.new('/path/to/fake-cpi/bin/cpi', director_uuid, cpi_config_properties ) }
      let(:logger) { double }
      before do
        allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        allow(logger).to receive(:debug)
      end

      it 'passes the properties in context to the cpi' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = {'director_uuid' => director_uuid, 'request_id' => request_id}.merge(cpi_config_properties)
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json}})

        expect(Open3).to receive(:capture3).with(expected_env, expected_cmd, stdin_data: expected_stdin, unsetenv_others: true)
        call_cpi_method
      end

      it 'redacts properties from cpi config in logs' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = {'director_uuid' => director_uuid, 'request_id' => request_id}.merge(cpi_config_properties)
        redacted_context = {
            'director_uuid' => director_uuid,
            'request_id' => request_id,
            'key1' => '<redacted>',
            'key2' => '<redacted>'
        }

        expected_arguments = arguments.clone
        if method == :create_vm
          expected_arguments[2] = {'cloud' => '<redacted>'}
          expected_arguments[5] = {
            'bosh' => {
              'group' => 'my-group',
              'groups' => ['my-first-group'],
              'password' => '<redacted>'
            },
            'other' => '<redacted>'
          }
        elsif method == :create_disk
          expected_arguments[1] = {'type' => '<redacted>'}
        end

        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json}})
        expected_log = %(External CPI sending request: {"method":"#{method}","arguments":#{expected_arguments.to_json},"context":#{redacted_context.to_json}} with command: #{expected_cmd})
        expect(logger).to receive(:debug).with(expected_log)

        expect(Open3).to receive(:capture3).with(expected_env, expected_cmd, stdin_data: expected_stdin, unsetenv_others: true)
        call_cpi_method
      end
    end

    describe 'result' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }

      it 'returns result' do
        expect(call_cpi_method).to eq('fake-result')
      end
    end

    describe 'log' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }

      it 'saves the log and stderr in task cpi log' do
        call_cpi_method
        expect(File.read(cpi_log_path)).to eq('fake-logfake-stderr-data')
      end

      it 'adds to existing file if for a given task several cpi requests were made' do
        external_cpi.public_send(method, *arguments)
        external_cpi.public_send(method, *arguments)
        expect(File.read(cpi_log_path)).to eq('fake-logfake-stderr-datafake-logfake-stderr-data')
      end

      context 'when no stderr' do
        before {
          allow(Open3).to receive(:capture3).and_return(cpi_response, nil, 0)
        }

        it 'saves the log in task cpi log' do
          call_cpi_method
          expect(File.read(cpi_log_path)).to eq('fake-log')
        end
      end
    end

    context 'when response is not a valid JSON' do
      let(:cpi_response) { 'invalid-json' }

      it 'raises an error' do
        expect { call_cpi_method }.to raise_error(Bosh::Clouds::ExternalCpi::InvalidResponse)
      end
    end

    context 'when response is in incorrect format' do
      let(:cpi_response) { JSON.dump(some_key: 'some_value') }

      it 'raises an error' do
        expect { call_cpi_method }.to raise_error(Bosh::Clouds::ExternalCpi::InvalidResponse)
      end
    end

    context 'when cpi command is not executable' do
      before { allow(File).to receive(:executable?).with('/path/to/fake-cpi/bin/cpi').and_return(false) }

      it 'raises MessageHandlerError' do
        expect {
          call_cpi_method
        }.to raise_error(
          Bosh::Clouds::ExternalCpi::NonExecutable,
          "Failed to run cpi: '/path/to/fake-cpi/bin/cpi' is not executable",
        )
      end
    end

    describe 'error response' do
      def self.it_raises_an_error(error_class, error_type = error_class.name, message = 'fake-error-message')
        let(:cpi_response) do
          JSON.dump(
            result: nil,
            error: {
              type: error_type,
              message: message,
              ok_to_retry: false,
            },
            log: 'fake-log',
          )
        end

        it 'raises an error constructed from error response' do
          expect { call_cpi_method }.to raise_error(error_class, /CPI error '#{error_type}' with message '#{message}' in '#{method}' CPI method/)
        end

        it 'saves log and stderr' do
          begin
            call_cpi_method
          rescue
            expect(File.read(cpi_log_path)).to eq('fake-logfake-stderr-data')
          else
            fail 'It should throw exception'
          end
        end
      end

      def self.it_raises_an_error_with_ok_to_retry(error_class)
        let(:cpi_response) do
          JSON.dump(
            result: nil,
            error: {
              type: error_class.name,
              message: 'fake-error-message',
              ok_to_retry: true,
            },
            log: 'fake-log',
          )
        end

        it 'raises an error constructed from error response' do
          expect {
            call_cpi_method
          }.to raise_error do |error|
            expect(error.class).to eq(error_class)
            expect(error.message).to eq("CPI error '#{error_class}' with message 'fake-error-message' in '#{method}' CPI method")
            expect(error.ok_to_retry).to eq(true)
          end
        end
      end

      context 'when cpi returns CpiError error' do
        it_raises_an_error(Bosh::Clouds::CpiError)
      end

      context 'when cpi returns NotImplemented error' do
        it_raises_an_error(Bosh::Clouds::NotImplemented)
      end

      context 'when cpi returns InvalidCall error' do
        it_raises_an_error(Bosh::Clouds::ExternalCpi::UnknownError, 'InvalidCall')

        context 'when method not implemented by the cpi' do
          it_raises_an_error(Bosh::Clouds::NotImplemented, 'InvalidCall', 'Method is not known, got something')
        end
      end

      context 'when cpi returns CloudError error' do
        it_raises_an_error(Bosh::Clouds::CloudError)

        context 'when method not implemented by the cpi' do
          it_raises_an_error(Bosh::Clouds::NotImplemented, 'Bosh::Clouds::CloudError', 'Invalid Method: something')
        end
      end

      context 'when cpi returns VMNotFound error' do
        it_raises_an_error(Bosh::Clouds::VMNotFound)
      end

      context 'when cpi returns a NoDiskSpace error' do
        it_raises_an_error_with_ok_to_retry(Bosh::Clouds::NoDiskSpace)
      end

      context 'when cpi returns a DiskNotAttached error' do
        it_raises_an_error_with_ok_to_retry(Bosh::Clouds::DiskNotAttached)
      end

      context 'when cpi returns a DiskNotFound error' do
        it_raises_an_error_with_ok_to_retry(Bosh::Clouds::DiskNotFound)
      end

      context 'when cpi returns a VMCreationFailed error' do
        it_raises_an_error_with_ok_to_retry(Bosh::Clouds::VMCreationFailed)
      end

      context 'when cpi raises unrecognizable error' do
        it_raises_an_error(Bosh::Clouds::ExternalCpi::UnknownError, 'FakeUnrecognizableError', 'Something went \'wrong\'')
      end
    end

    context 'when exit status is non zero' do
      let(:exit_status) { instance_double('Process::Status', exitstatus: 123) }

      it 'ignores the exit status and returns result because the CPI script currently catches CPI error and returns response' do
        expect { call_cpi_method }.to_not raise_error
      end
    end
  end

  describe '#current_vm_id' do
    it_calls_cpi_method(:current_vm_id)
  end

  describe '#create_stemcell' do
    it_calls_cpi_method(:create_stemcell, 'fake-stemcell-image-path', {'cloud' => 'props'})
  end

  describe '#delete_stemcell' do
    it_calls_cpi_method(:delete_stemcell, 'fake-stemcell-cid')
  end

  describe '#create_vm' do
    it_calls_cpi_method(:create_vm,
      'fake-agent-id',
      'fake-stemcell-cid',
      {'cloud' => 'props'},
      {'net' => 'props'},
      ['fake-disk-cid'],
      {
        'bosh' => {
          'group' => 'my-group',
          'groups' => ['my-first-group'],
          'password' => 'my-secret-password'
        },
        'other' => 'value'
      }
    )
  end

  describe '#delete_vm' do
    it_calls_cpi_method(:delete_vm, 'fake-vm-cid')
  end

  describe '#has_vm' do
    it_calls_cpi_method(:has_vm, 'fake-vm-cid')
  end

  describe '#reboot_vm' do
    it_calls_cpi_method(:reboot_vm, 'fake-vm-cid')
  end

  describe '#set_vm_metadata' do
    it_calls_cpi_method(:set_vm_metadata, 'fake-vm-cid', {'metadata' => 'hash'})
  end

  describe '#set_disk_metadata' do
    it_calls_cpi_method(:set_disk_metadata, 'fake-disk-cid', {'metadata' => 'hash'})
  end

  describe '#create_disk' do
    it_calls_cpi_method(:create_disk, 100_000, {'type' => 'gp2'}, 'fake-vm-cid')
  end

  describe '#has_disk' do
    it_calls_cpi_method(:has_disk, 'fake-disk-cid')
  end

  describe '#delete_disk' do
    it_calls_cpi_method(:delete_disk, 'fake-disk-cid')
  end

  describe '#attach_disk' do
    it_calls_cpi_method(:attach_disk, 'fake-vm-cid', 'fake-disk-cid')
  end

  describe '#detach_disk' do
    it_calls_cpi_method(:detach_disk, 'fake-vm-cid', 'fake-disk-cid')
  end

  describe '#snapshot_disk' do
    it_calls_cpi_method(:snapshot_disk, 'fake-disk-cid')
  end

  describe '#delete_snapshot' do
    it_calls_cpi_method(:delete_snapshot, 'fake-snapshot-cid')
  end

  describe '#resize_disk' do
    it_calls_cpi_method(:resize_disk, 'fake-disk-cid', 1024)
  end

  describe '#get_disks' do
    it_calls_cpi_method(:get_disks, 'fake-vm-cid')
  end

  describe '#ping' do
    it_calls_cpi_method(:ping)
  end

  describe '#info' do
    it_calls_cpi_method(:info)
  end
end
