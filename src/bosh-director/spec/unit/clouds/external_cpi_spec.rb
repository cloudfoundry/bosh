require 'spec_helper'
require 'fakefs/spec_helpers'

describe Bosh::Clouds::ExternalCpi do
  include FakeFS::SpecHelpers

  subject(:external_cpi) { described_class.new('/path/to/fake-cpi/bin/cpi', 'fake-director-uuid', logger) }

  def self.it_calls_cpi_method(method, *arguments, api_version: 1)
    define_method(:call_cpi_method) do
      external_cpi.public_send(method, *arguments)
    end

    before { allow(File).to receive(:executable?).with('/path/to/fake-cpi/bin/cpi').and_return(true) }

    let(:method) { method }
    let(:cpi_response) { JSON.dump(result: nil, error: nil, log: '') }
    let(:cpi_error) { 'fake-stderr-data' }
    let(:cpi_log_path) { '/var/vcap/task/5/cpi' }
    let(:logger) { double(:logger, debug: nil, info: nil) }
    let(:config) { double('Bosh::Director::Config', logger: logger, cpi_task_log: cpi_log_path) }
    before { stub_const('Bosh::Director::Config', config) }
    before { FileUtils.mkdir_p('/var/vcap/task/5') }

    let(:wait_thread) do
      double('Process::Waiter', value: double('Process::Status', exitstatus: exit_status))
    end

    let(:stdin)  { instance_double('IO') }
    let(:stdout) { instance_double('IO') }
    let(:stderr) { instance_double('IO') }

    before do
      allow(stdin).to receive(:write)
      allow(stdin).to receive(:close)
      allow(IO).to receive(:select).and_return([[stdout, stderr]])

      allow(stdout).to receive(:fileno).and_return(1)

      stdout_reponse_values = [cpi_response, nil, cpi_response, nil, cpi_response, nil]
      allow(stdout).to receive(:readline_nonblock) { stdout_reponse_values.shift || raise(EOFError) }

      allow(stderr).to receive(:fileno).and_return(2)

      stderr_reponse_values = [cpi_error, nil, cpi_error, nil, cpi_error, nil]
      allow(stderr).to receive(:readline_nonblock) { stderr_reponse_values.shift || raise(EOFError) }

      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)

      allow(Random).to receive(:rand).and_return('fake-request-id')
    end

    let(:exit_status) { instance_double('Process::Status', exitstatus: 0) }

    context 'api version specified' do
      before do
        subject.request_cpi_api_version = api_version
      end

      it 'should call cpi binary with correct arguments' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":) +
                         %({"director_uuid":"fake-director-uuid","request_id":"cpi-fake-request-id"},"api_version":#{api_version}})

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, unsetenv_others: true)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end
    end

    context 'api version not specified' do
      it 'should call cpi binary with correct arguments' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":) +
                         %({"director_uuid":"fake-director-uuid","request_id":"cpi-fake-request-id"}})

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, unsetenv_others: true)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end
    end

    context 'if properties from cpi config are given' do
      let(:director_uuid) {'fake-director-uuid'}
      let(:request_id) {'cpi-fake-request-id'}
      let(:cpi_config_properties) do
        { 'key1' => { 'nestedkey1' => 'nestedvalue1' }, 'key2' => 'value2' }
      end
      let(:options) do
        {
          properties_from_cpi_config: cpi_config_properties
        }
      end
      let(:external_cpi) { described_class.new('/path/to/fake-cpi/bin/cpi', director_uuid, logger, options) }

      it 'passes the properties in context to the cpi' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = {'director_uuid' => director_uuid, 'request_id' => request_id}.merge(cpi_config_properties)
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json}})

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, unsetenv_others: true)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end

      it 'logs requests and responses with request id' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        lines = []
        allow(logger).to receive(:debug) { |line| lines << line }

        call_cpi_method
        expect(lines[0]).to start_with "[external-cpi] [#{request_id}] request"
        expect(lines[1]).to start_with "[external-cpi] [#{request_id}] response"
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
          expected_arguments[3] = redacted_network_settings
          expected_arguments[5] = {
            'bosh' => {
              'group' => 'my-group',
              'groups' => ['my-first-group'],
              'tags' => { 'tag' => 'tagvalue' },
              'password' => '<redacted>'
            },
            'other' => '<redacted>'
          }
        elsif method == :create_disk
          expected_arguments[1] = {'type' => '<redacted>'}
        end

        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json}})
        expected_log = %([external-cpi] [#{request_id}] request: {"method":"#{method}","arguments":#{expected_arguments.to_json},"context":#{redacted_context.to_json}} with command: #{expected_cmd})
        expect(logger).to receive(:debug).with(expected_log)

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, unsetenv_others: true)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end
    end

    context 'when stemcell api_version is given' do
      let(:director_uuid) {'fake-director-uuid'}
      let(:request_id) {'cpi-fake-request-id'}
      let(:stemcell_api_version) { 5 }
      let(:options) do
        {
          stemcell_api_version: stemcell_api_version
        }
      end

      let(:external_cpi) { described_class.new('/path/to/fake-cpi/bin/cpi', director_uuid, logger, options) }

      it 'puts api_version in context passed to cpi and logs it in CPI logs' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = {'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp'}
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = {
          'director_uuid' => director_uuid,
          'request_id' => request_id,
          'vm' => {
            'stemcell' => {
              'api_version' => 5
            }
          }
        }
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json}})
        expect(logger).to receive(:debug).with(/api_version/)

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, unsetenv_others: true)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end

      it 'logs requests and responses with request id' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        lines = []
        allow(logger).to receive(:debug) { |line| lines << line }

        call_cpi_method
        expect(lines[0]).to start_with "[external-cpi] [#{request_id}] request"
        expect(lines[1]).to start_with "[external-cpi] [#{request_id}] response"
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
        expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-log')
      end

      it 'adds to existing file if for a given task several cpi requests were made' do
        call_cpi_method
        call_cpi_method
        expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-logfake-stderr-datafake-log')
      end

      context 'when no stderr' do
        let(:cpi_error) { nil }
        # before {
        #   allow(Open3).to receive(:capture3).and_return(cpi_response, nil, 0)
        # }

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
        let(:request_id) { 'cpi-fake-request-id' }
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
          expect { call_cpi_method }.to raise_error(
            error_class,
            /CPI error '#{error_type}' with message '#{message}' in '#{method}' CPI method \(CPI request ID: '#{request_id}'\)/,
          )
        end

        it 'saves log and stderr' do
          begin
            call_cpi_method
          rescue
            expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-log')
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
            expect(error.message).to eq("CPI error '#{error_class}' with message 'fake-error-message' in '#{method}'" \
            " CPI method \(CPI request ID: 'cpi-fake-request-id'\)")
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
    context 'when cloud_properties in network settings is valid and defined' do
      let(:redacted_network_settings) do
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {
              'smurf_1' => '<redacted>'
            },
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1'
          }
        }
      end

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        {'cloud' => 'props'},
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {
              'smurf_1' => 'cat_1_manual_network'
            },
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1'
          }
        },
        ['fake-disk-cid'],
        {
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'tags' => { 'tag' => 'tagvalue' },
            'password' => 'my-secret-password'
          },
          'other' => 'value'
        }
      )
    end

    context 'when network settings hash is nil' do
      let(:redacted_network_settings) { nil }

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        {'cloud' => 'props'},
        nil,
        ['fake-disk-cid'],
        {
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'tags' => { 'tag' => 'tagvalue' },
            'password' => 'my-secret-password'
          },
          'other' => 'value'
        }
      )
    end

    context 'when network settings is not a hash' do
      let(:redacted_network_settings) { 'I am not a hash' }

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        {'cloud' => 'props'},
        'I am not a hash',
        ['fake-disk-cid'],
        {
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'tags' => { 'tag' => 'tagvalue' },
            'password' => 'my-secret-password'
          },
          'other' => 'value'
        }
      )
    end

    context 'when network settings hash cloud properties is absent' do
      let(:redacted_network_settings) do
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1'
          }
        }
      end

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        {'cloud' => 'props'},
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1'
          }
        },
        ['fake-disk-cid'],
        {
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'tags' => { 'tag' => 'tagvalue' },
            'password' => 'my-secret-password'
          },
          'other' => 'value'
        }
      )
    end

    context 'when network settings hash cloud properties is not a hash' do
      let(:redacted_network_settings) do
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1',
            'cloud_properties' => 'i am not a hash'
          }
        }
      end

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        {'cloud' => 'props'},
        {
          'net' => {
            'type' => 'manual',
            'ip' => '10.10.0.2',
            'netmask' => '255.255.255.0',
            'default' => ['dns', 'gateway'],
            'dns' => ['10.10.0.2'],
            'gateway' => '10.10.0.1',
            'cloud_properties' => 'i am not a hash'
          }
        },
        ['fake-disk-cid'],
        {
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'tags' => { 'tag' => 'tagvalue' },
            'password' => 'my-secret-password'
          },
          'other' => 'value'
        }
      )
    end
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

  context 'Fix for a deadlock scenario when a cpi sub-process sends an incomplete line (missing "\n") to STDOUT' do
    let(:logger) { Logging::Logger.new('ExternalCpi') }
    let(:cpi_log_path) { '/var/vcap/task/5/cpi' }
    let(:config) { double('Bosh::Director::Config', logger: logger, cpi_task_log: cpi_log_path) }
    let(:external_cpi) { described_class.new(asset_path("bin/dummy_cpi"), 'fake-director-uuid', logger) }

    before do
      stub_const('Bosh::Director::Config', config)
      FileUtils.mkdir_p('/var/vcap/task/5')
      allow(File).to receive(:executable?).with(asset_path('bin/dummy_cpi')).and_return(true)
      allow(Open3).to receive(:popen3).and_wrap_original do |original_method, *args, &block|
        # We need to make sure Open3.popen3 gets called with a env path where ruby exists.
        # We happen to know it is /usr/local/bin/ in this case.
        args[0]['PATH'] += ':/usr/local/bin'
        original_method.call(*args, &block)
      end
    end

    it 'does not deadlock' do
      Timeout::timeout(60) do
        result = external_cpi.info
        expect(result).to eq 'OK'
      end
    end
  end
end
