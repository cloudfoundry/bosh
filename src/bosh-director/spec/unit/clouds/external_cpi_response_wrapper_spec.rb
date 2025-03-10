require 'spec_helper'
require 'fakefs/spec_helpers'

describe Bosh::Clouds::ExternalCpiResponseWrapper do
  include FakeFS::SpecHelpers

  let(:cpi_response) { JSON.dump(result: nil, error: nil, log: '') }
  let(:cpi_error) { 'fake-stderr-data' }
  let(:additional_expected_args) { nil }
  let(:exit_status) { instance_double('Process::Status', exitstatus: 0) }
  let(:cpi_log_path) { '/var/vcap/task/5/cpi' }

  let(:logger) { double(:logger, debug: nil) }
  let(:config) { double('Bosh::Director::Config', logger: logger, cpi_task_log: cpi_log_path, preferred_cpi_api_version: 2) }
  let(:cloud) { Bosh::Clouds::ExternalCpi.new('/path/to/fake-cpi/bin/cpi', 'fake-director-uuid', logger) }

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
  end

  before(:each) do
    stub_const('Bosh::Director::Config', config)
  end

  subject { described_class.new(cloud, cpi_api_version) }
  def self.it_should_raise_error(method, error_type, error_msg, *arguments)
    define_method(:call_cpi_method) { subject.public_send(method, *arguments) }

    before do
      allow(File).to receive(:executable?).with('/path/to/fake-cpi/bin/cpi').and_return(true)
      FileUtils.mkdir_p('/var/vcap/task/5')
      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
      allow(Random).to receive(:rand).and_return('fake-request-id')
    end

    it 'should raise error' do
      expect { call_cpi_method }.to raise_error(error_type, error_msg)
    end
  end

  def self.it_calls_cpi_method(method, *arguments)
    define_method(:call_cpi_method) { subject.public_send(method, *arguments) }

    let(:method) { method }

    before do
      allow(File).to receive(:executable?).with('/path/to/fake-cpi/bin/cpi').and_return(true)
      FileUtils.mkdir_p('/var/vcap/task/5')
      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
      allow(Random).to receive(:rand).and_return('fake-request-id')
    end

    it 'should call cpi binary with correct arguments' do
      stub_const('ENV', 'TMPDIR' => '/some/tmp')

      expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp' }
      expected_cmd = '/path/to/fake-cpi/bin/cpi'
      arguments << additional_expected_args unless additional_expected_args.nil?
      expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":{"director_uuid":"fake-director-uuid","request_id":"cpi-fake-request-id"},"api_version":#{cpi_api_version}})

      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
      expect(call_cpi_method).to eq(expected_response)
    end

    context 'if properties from cpi config are given' do
      let(:director_uuid) { 'fake-director-uuid' }
      let(:request_id) { 'cpi-fake-request-id' }
      let(:cpi_config_properties) { { 'key1' => { 'nestedkey1' => 'nestedvalue1' }, 'key2' => 'value2' } }
      let(:options) do
        {
          properties_from_cpi_config: cpi_config_properties,
        }
      end
      let(:cloud) { Bosh::Clouds::ExternalCpi.new('/path/to/fake-cpi/bin/cpi', director_uuid, logger, options) }

      it 'passes the properties in context to the cpi' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp' }
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = { 'director_uuid' => director_uuid, 'request_id' => request_id }.merge(cpi_config_properties)
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json},"api_version":#{cpi_api_version}})
        lines = []
        allow(logger).to receive(:debug) { |line| lines << line }

        expect(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
        expect(lines[0]).to start_with "[external-cpi] [#{request_id}] request"
        expect(lines[1]).to start_with "[external-cpi] [#{request_id}] response"
      end

      it 'redacts properties from cpi config in logs' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp' }
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = { 'director_uuid' => director_uuid, 'request_id' => request_id }.merge(cpi_config_properties)
        redacted_context = {
          'director_uuid' => director_uuid,
          'request_id' => request_id,
          'key1' => '<redacted>',
          'key2' => '<redacted>',
        }

        expected_arguments = arguments.clone
        if method == :create_vm
          expected_arguments[2] = { 'cloud' => '<redacted>' }
          expected_arguments[3] = redacted_network_settings
          expected_arguments[5] = {
            'bosh' => {
              'group' => 'my-group',
              'groups' => ['my-first-group'],
              'password' => '<redacted>',
            },
            'other' => '<redacted>',
          }
        elsif method == :create_disk
          expected_arguments[1] = { 'type' => '<redacted>' }
        elsif method == :create_stemcell && cpi_api_version >= 3
          # expected_arguments[2] = { "tags" => {"any":"value"} }
        end

        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json},"api_version":#{cpi_api_version}})
        expected_request_log = %([external-cpi] [#{request_id}] request: {"method":"#{method}","arguments":#{expected_arguments.to_json},"context":#{redacted_context.to_json},"api_version":#{cpi_api_version}} with command: #{expected_cmd})
        expect(logger).to receive(:debug).with(expected_request_log)

        expect(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method
      end
    end

    context 'when stemcell api_version is given' do
      let(:director_uuid) { 'fake-director-uuid' }
      let(:request_id) { 'cpi-fake-request-id' }
      let(:stemcell_api_version) { 5 }
      let(:options) do
        {
          stemcell_api_version: stemcell_api_version,
        }
      end

      let(:cloud) { Bosh::Clouds::ExternalCpi.new('/path/to/fake-cpi/bin/cpi', director_uuid, logger, options) }
      let(:logger) { double }

      before do
        allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
        allow(logger).to receive(:info)
        allow(logger).to receive(:debug)
      end

      it 'puts api_version in context passed to cpi and logs it in CPI logs' do
        stub_const('ENV', 'TMPDIR' => '/some/tmp')

        expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp' }
        expected_cmd = '/path/to/fake-cpi/bin/cpi'
        context = {
          'director_uuid' => director_uuid,
          'request_id' => request_id,
          'vm' => {
            'stemcell' => {
              'api_version' => 5,
            },
          },
        }
        expected_stdin = %({"method":"#{method}","arguments":#{arguments.to_json},"context":#{context.to_json},"api_version":#{cpi_api_version}})
        lines = []
        allow(logger).to receive(:debug) { |line| lines << line }

        expect(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
        expect(stdin).to receive(:write).with(expected_stdin)
        call_cpi_method

        expect(lines[0]).to start_with "[external-cpi] [#{request_id}] request"
        expect(lines[1]).to start_with "[external-cpi] [#{request_id}] response"
      end
    end

    describe 'log' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }

      it 'saves the log and stderr in task cpi log' do
        call_cpi_method
        expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-log')
        call_cpi_method
        expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-logfake-stderr-datafake-log')
      end

      context 'when no stderr' do
        let(:cpi_error) { nil }
        before do
          allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread)
        end

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
        expect do
          call_cpi_method
        end.to raise_error(
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
          expect(File.read(cpi_log_path)).to eq('fake-stderr-datafake-log')
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
          expect do
            call_cpi_method
          end.to raise_error do |error|
            expect(error.class).to eq(error_class)
            expect(error.message).to eq("CPI error '#{error_class}' with message 'fake-error-message' in '#{method}'"\
              " CPI method (CPI request ID: 'cpi-fake-request-id')")
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

  describe 'supported CPI versions' do
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi).as_null_object }

    it 'raises an exception if the CPI API version is not supported' do
      expect { Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud, 100) }.to raise_error(Bosh::Clouds::NotSupported)
    end
  end

  describe 'when cpi_version is >= 3' do
    let(:cpi_api_version) { 3 }
    let(:config) { double('Bosh::Director::Config', logger: logger, cpi_task_log: cpi_log_path, preferred_cpi_api_version: 3) }
    
    describe '#create_stemcell' do

    let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }
    let(:expected_response) { 'fake-result' }

    it_calls_cpi_method(
        :create_stemcell,
        'fake-stemcell-cid',
        { 'cloud' => 'props' },
        { 'tags' => {"any": "value"} }
      )

    end
  end

  describe 'when cpi_version is 2' do
    let(:cpi_api_version) { 2 }

    describe '#create_vm' do
      let(:redacted_network_settings) { nil }
      let(:instance_cid) { 'i-0478554' }
      let(:networks) do
        {
          'private' => {
            'type' => 'manual',
            'netmask' => '255.255.255.0',
            'gateway' => '10.230.13.1',
            'ip' => '10.230.13.6',
            'default' => %w[dns gateway],
            'cloud_properties' => { 'net_id' => 'd29fdb0d-44d8-4e04-818d-5b03888f8eaa' },
          },
          'public' => {
            'type' => 'vip',
            'ip' => '173.101.112.104',
            'cloud_properties' => {},
          },
        }
      end
      let(:cpi_response) { JSON.dump(result: [instance_cid, networks], error: nil, log: 'fake-log') }
      let(:expected_response) { [instance_cid, networks] }

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        { 'cloud' => 'props' },
        nil,
        ['fake-disk-cid'],
        'bosh' => {
          'group' => 'my-group',
          'groups' => ['my-first-group'],
          'password' => 'my-secret-password',
        },
        'other' => 'value',
      )

      context 'when network settings hash cloud properties is absent' do
        let(:redacted_network_settings) do
          {
            'net' => {
              'type' => 'manual',
              'ip' => '10.10.0.2',
              'netmask' => '255.255.255.0',
              'default' => %w[dns gateway],
              'dns' => ['10.10.0.2'],
              'gateway' => '10.10.0.1',
            },
          }
        end

        it_calls_cpi_method(
          :create_vm,
          'fake-agent-id',
          'fake-stemcell-cid',
          { 'cloud' => 'props' },
          {
            'net' => {
              'type' => 'manual',
              'ip' => '10.10.0.2',
              'netmask' => '255.255.255.0',
              'default' => %w[dns gateway],
              'dns' => ['10.10.0.2'],
              'gateway' => '10.10.0.1',
            },
          },
          ['fake-disk-cid'],
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'password' => 'my-secret-password',
          },
          'other' => 'value',
        )
      end
    end

    describe('#attach_disk') do
      let(:cpi_response) { JSON.dump(result: '/fake/disk-hint', error: nil, log: 'fake-log') }
      let(:expected_response) { '/fake/disk-hint' }
      it_calls_cpi_method(:attach_disk, 'fake-vm-cid', 'fake-disk-cid')

      context 'when v2 cpi request does NOT return disk_hint' do
        let(:cpi_response) { JSON.dump(result: nil, error: nil, log: 'fake-log') }
        it_should_raise_error(
          :attach_disk,
          Bosh::Clouds::AttachDiskResponseError,
          'No disk_hint',
          'fake-vm-cid', 'fake-disk-cid'
        )
      end
    end

    describe 'forwards all other methods without change' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }
      let(:expected_response) { 'fake-result' }

      context('#current_vm_id') do
        it_calls_cpi_method(:current_vm_id)
      end

      context('#create_stemcell') do
        it_calls_cpi_method(:create_stemcell, 'fake-stemcell-image-path', 'cloud' => 'props')
      end

      context('#delete_stemcell') do
        it_calls_cpi_method(:delete_stemcell, 'fake-stemcell-cid')
      end

      context('#delete_vm') do
        it_calls_cpi_method(:delete_vm, 'fake-vm-cid')
      end

      context('#create_network') do
        network_definition = { 'range' => '192.68.1.1' }
        it_calls_cpi_method(:create_network, network_definition)
      end

      context('#delete_network') do
        it_calls_cpi_method(:delete_vm, 'fake-network-id')
      end

      context('#has_vm') do
        it_calls_cpi_method(:has_vm, 'fake-vm-cid')
      end

      context('#reboot_vm') do
        it_calls_cpi_method(:reboot_vm, 'fake-vm-cid')
      end

      context('#set_vm_metadata') do
        it_calls_cpi_method(:set_vm_metadata, 'fake-vm-cid', 'metadata' => 'hash')
      end

      context('#set_disk_metadata') do
        it_calls_cpi_method(:set_disk_metadata, 'fake-disk-cid', 'metadata' => 'hash')
      end

      context('#create_disk') do
        it_calls_cpi_method(:create_disk, 100_000, { 'type' => 'gp2' }, 'fake-vm-cid')
      end

      context('#has_disk') do
        it_calls_cpi_method(:has_disk, 'fake-disk-cid')
      end

      context('#delete_disk') do
        it_calls_cpi_method(:delete_disk, 'fake-disk-cid')
      end

      context('#detach_disk') do
        it_calls_cpi_method(:detach_disk, 'fake-vm-cid', 'fake-disk-cid')
      end

      context('#snapshot_disk') do
        it_calls_cpi_method(:snapshot_disk, 'fake-disk-cid')
      end

      context('#delete_snapshot') do
        it_calls_cpi_method(:delete_snapshot, 'fake-snapshot-cid')
      end

      context('#resize_disk') do
        it_calls_cpi_method(:resize_disk, 'fake-disk-cid', 1024)
      end

      context('#get_disks') do
        it_calls_cpi_method(:get_disks, 'fake-vm-cid')
      end

      context('#ping') do
        it_calls_cpi_method(:ping)
      end

      context('#info') do
        it_calls_cpi_method(:info)
      end
    end
  end

  describe 'when cpi_version is 1' do
    let(:cpi_api_version) { 1 }

    describe '#create_vm' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }
      let(:redacted_network_settings) { nil }
      let(:expected_response) { ['fake-result'] }

      it_calls_cpi_method(
        :create_vm,
        'fake-agent-id',
        'fake-stemcell-cid',
        { 'cloud' => 'props' },
        nil,
        ['fake-disk-cid'],
        'bosh' => {
          'group' => 'my-group',
          'groups' => ['my-first-group'],
          'password' => 'my-secret-password',
        },
        'other' => 'value',
      )

      context 'when network settings hash cloud properties is absent' do
        let(:expected_response) { ['fake-result'] }
        let(:redacted_network_settings) do
          {
            'net' => {
              'type' => 'manual',
              'ip' => '10.10.0.2',
              'netmask' => '255.255.255.0',
              'default' => %w[dns gateway],
              'dns' => ['10.10.0.2'],
              'gateway' => '10.10.0.1',
            },
          }
        end

        it_calls_cpi_method(
          :create_vm,
          'fake-agent-id',
          'fake-stemcell-cid',
          { 'cloud' => 'props' },
          {
            'net' => {
              'type' => 'manual',
              'ip' => '10.10.0.2',
              'netmask' => '255.255.255.0',
              'default' => %w[dns gateway],
              'dns' => ['10.10.0.2'],
              'gateway' => '10.10.0.1',
            },
          },
          ['fake-disk-cid'],
          'bosh' => {
            'group' => 'my-group',
            'groups' => ['my-first-group'],
            'password' => 'my-secret-password',
          },
          'other' => 'value',
        )
      end
    end

    describe('#attach_disk') do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }
      let(:expected_response) { nil }
      it_calls_cpi_method(:attach_disk, 'fake-vm-cid', 'fake-disk-cid')
    end

    describe 'forwards all other methods without change' do
      let(:cpi_response) { JSON.dump(result: 'fake-result', error: nil, log: 'fake-log') }
      let(:expected_response) { 'fake-result' }

      context('#current_vm_id') do
        it_calls_cpi_method(:current_vm_id)
      end

      context('#create_stemcell') do
        it_calls_cpi_method(:create_stemcell, 'fake-stemcell-image-path', 'cloud' => 'props')
      end

      context('#delete_stemcell') do
        it_calls_cpi_method(:delete_stemcell, 'fake-stemcell-cid')
      end

      context('#delete_vm') do
        it_calls_cpi_method(:delete_vm, 'fake-vm-cid')
      end

      context('#has_vm') do
        it_calls_cpi_method(:has_vm, 'fake-vm-cid')
      end

      context('#reboot_vm') do
        it_calls_cpi_method(:reboot_vm, 'fake-vm-cid')
      end

      context('#set_vm_metadata') do
        it_calls_cpi_method(:set_vm_metadata, 'fake-vm-cid', 'metadata' => 'hash')
      end

      context('#set_disk_metadata') do
        it_calls_cpi_method(:set_disk_metadata, 'fake-disk-cid', 'metadata' => 'hash')
      end

      context('#create_disk') do
        it_calls_cpi_method(:create_disk, 100_000, { 'type' => 'gp2' }, 'fake-vm-cid')
      end

      context('#has_disk') do
        it_calls_cpi_method(:has_disk, 'fake-disk-cid')
      end

      context('#delete_disk') do
        it_calls_cpi_method(:delete_disk, 'fake-disk-cid')
      end

      context('#detach_disk') do
        it_calls_cpi_method(:detach_disk, 'fake-vm-cid', 'fake-disk-cid')
      end

      context('#snapshot_disk') do
        it_calls_cpi_method(:snapshot_disk, 'fake-disk-cid')
      end

      context('#delete_snapshot') do
        it_calls_cpi_method(:delete_snapshot, 'fake-snapshot-cid')
      end

      context('#resize_disk') do
        it_calls_cpi_method(:resize_disk, 'fake-disk-cid', 1024)
      end

      context('#get_disks') do
        it_calls_cpi_method(:get_disks, 'fake-vm-cid')
      end

      context('#ping') do
        it_calls_cpi_method(:ping)
      end

      context('#info') do
        it_calls_cpi_method(:info)
      end
    end
  end
end
