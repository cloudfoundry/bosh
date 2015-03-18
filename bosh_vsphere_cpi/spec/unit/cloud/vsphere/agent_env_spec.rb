require 'spec_helper'
# require 'fakefs/spec_helpers'

module VSphereCloud
  describe AgentEnv do
    include FakeFS::SpecHelpers

    subject(:agent_env) { described_class.new(client, file_provider, cloud_searcher) }

    let(:client) { instance_double('VSphereCloud::Client') }
    let(:file_provider) { double('VSphereCloud::FileProvider') }
    let(:cloud_searcher) { double('VSphereCloud::CloudSearcher') }

    let(:location) do
      {
        datacenter: 'fake-datacenter-name 1',
        datastore: 'fake-datastore-name 1',
        vm: 'fake-vm-name',
      }
    end

    describe '#get_current_env' do
      let(:vm) { instance_double('VimSdk::Vim::Vm') }

      before do
        allow(client).to receive(:get_cdrom_device).with(vm).and_return(cdrom_device)
      end

      let(:cdrom_device) do
        instance_double(
          'VimSdk::Vim::Vm::Device::VirtualCdrom',
          backing: cdrom_backing
        )
      end

      before do
        allow(cdrom_device).to receive(:kind_of?).
          with(VimSdk::Vim::Vm::Device::VirtualCdrom).and_return(true)
      end

      let(:cdrom_backing) do
        instance_double('VimSdk::Vim::Vm::Device::VirtualCdrom::IsoBackingInfo',
          datastore: cdrom_datastore,
          file_name: '[fake-datastore-name 1] fake-vm-name/env.iso'
        )
      end

      let(:cdrom_datastore) { instance_double('VimSdk::Vim::Datastore', name: 'fake-datastore-name 1') }

      it 'gets current agent environment from fetched file' do
        expect(file_provider).to receive(:fetch_file).with(
          'fake-datacenter-name 1',
          'fake-datastore-name 1',
          'fake-vm-name/env.json',
        ).and_return('{"fake-response-json" : "some-value"}')

        expect(agent_env.get_current_env(vm, 'fake-datacenter-name 1')).to eq({'fake-response-json' => 'some-value'})
      end

      it 'raises if env.json is empty' do
        allow(file_provider).to receive(:fetch_file).with(
          'fake-datacenter-name 1',
          'fake-datastore-name 1',
          'fake-vm-name/env.json',
        ).and_return(nil)

        expect {
          agent_env.get_current_env(vm, 'fake-datacenter-name 1')
        }.to raise_error(Bosh::Clouds::CloudError)
      end
    end

    describe '#clean_env' do
      let(:vm) do
        instance_double('VimSdk::Vim::VirtualMachine',
          config: double(:config, hardware: double(:hardware, device: [cdrom]))
        )
      end

      let(:cdrom_connectable_connected) { true }

      let(:cdrom) do
        VimSdk::Vim::Vm::Device::VirtualCdrom.new(
          connectable: VimSdk::Vim::Vm::Device::VirtualDevice::ConnectInfo.new(
            connected: cdrom_connectable_connected
          ),
          backing: cdrom_backing
        )
      end

      let(:cdrom_backing) do
        VimSdk::Vim::Vm::Device::VirtualCdrom::IsoBackingInfo.new(
          file_name: '[fake-old-datastore-name 1] fake-vm-name/env.iso'
        )
      end

      let(:datacenter) { instance_double('VimSdk::Vim::Datacenter') }
      before do
        allow(client).to receive(:get_cdrom_device).with(vm).and_return(cdrom)
        allow(client).to receive(:find_parent).with(vm, VimSdk::Vim::Datacenter).and_return(datacenter)
      end

      it 'deletes env.json and env.iso' do
        expect(client).to receive(:delete_path).with(datacenter, '[fake-old-datastore-name 1] fake-vm-name/env.json')
        expect(client).to receive(:delete_path).with(datacenter, '[fake-old-datastore-name 1] fake-vm-name/env.iso')

        agent_env.clean_env(vm)
      end

      context 'when no cdrom exists' do
        let(:cdrom) { nil }

        it 'does not delete anything' do
          expect(client).to_not receive(:delete_path)

          agent_env.clean_env(vm)
        end
      end
    end

    describe '#set_env' do
      let(:vm) do
        instance_double('VimSdk::Vim::VirtualMachine',
          config: double(:config, hardware: double(:hardware, device: [cdrom]))
        )
      end

      let(:env) { ['fake-json'] }
      let(:cdrom_connectable_connected) { true }

      let(:cdrom) do
        VimSdk::Vim::Vm::Device::VirtualCdrom.new(
          connectable: VimSdk::Vim::Vm::Device::VirtualDevice::ConnectInfo.new(
            connected: cdrom_connectable_connected
          ),
          backing: cdrom_backing
        )
      end

      let(:cdrom_backing) do
        VimSdk::Vim::Vm::Device::VirtualCdrom::IsoBackingInfo.new(
          file_name: '[fake-old-datastore-name 1] fake-vm-name/env.iso'
        )
      end

      let(:datacenter) { instance_double('VimSdk::Vim::Datacenter') }
      let(:vm_datastore) { instance_double('VimSdk::Vim::Datastore') }
      before do
        allow(cdrom).to receive(:kind_of?).with(VimSdk::Vim::Vm::Device::VirtualCdrom).and_return(true)
        allow(client).to receive(:get_cdrom_device).with(vm).and_return(cdrom)
        allow(client).to receive(:find_parent).with(vm, VimSdk::Vim::Datacenter).and_return(datacenter)
        allow(cloud_searcher).to receive(:get_managed_object).with(VimSdk::Vim::Datastore, name: 'fake-datastore-name 1').
          and_return(vm_datastore)
      end

      def it_disconnects_cdrom
        expect(client).to receive(:reconfig_vm) do |reconfig_vm, config_spec|
          expect(reconfig_vm).to eq(vm)
          device_changes = config_spec.device_change
          expect(device_changes.size).to eql(1)
          cdrom_change = device_changes.first
          expect(cdrom_change.device.connectable.connected).to eq(false)
        end
      end

      def it_cleans_up_old_env_files
        expect(client).to receive(:delete_path).with(datacenter, '[fake-old-datastore-name 1] fake-vm-name/env.json')
        expect(client).to receive(:delete_path).with(datacenter, '[fake-old-datastore-name 1] fake-vm-name/env.iso')
      end

      def it_uploads_environment_json(code = 204)
        expect(file_provider).to receive(:upload_file).with(
          'fake-datacenter-name 1',
          'fake-datastore-name 1',
          'fake-vm-name/env.json',
          '["fake-json"]'
        ).and_return(double(:response, code: code))
      end

      def it_generates_environment_iso(options = {})
        iso_generator = options.fetch(:iso_generator, 'genisoimage')
        exit_status = options.fetch(:exit_status, 0)

        allow(Dir).to receive(:mktmpdir) do |&blk|
          FileUtils.mkdir_p('/some/tmp/dir')
          blk.call('/some/tmp/dir')
        end

        expect(agent_env).to receive(:`).with("#{iso_generator} -o /some/tmp/dir/env.iso /some/tmp/dir/env 2>&1") do
          expect(File.read('/some/tmp/dir/env')).to eq('["fake-json"]')
          File.open('/some/tmp/dir/env.iso', 'w') { |f| f.write('iso contents') }
          allow($?).to receive(:exitstatus).and_return(exit_status)
        end
      end

      def it_uploads_environment_iso
        expect(file_provider).to receive(:upload_file).with(
          'fake-datacenter-name 1',
          'fake-datastore-name 1',
          'fake-vm-name/env.iso',
          'iso contents',
        ).and_return(double(:response, code: 204))
      end

      def it_reconfigures_cdrom
        expect(client).to receive(:reconfig_vm) do |reconfig_vm, config_spec|
          expect(reconfig_vm).to eq(vm)
          device_changes = config_spec.device_change
          expect(device_changes.size).to eql(1)
          cdrom_change = device_changes.first
          expect(cdrom_change.device.connectable.connected).to eq(true)
          expect(cdrom_change.device.backing.datastore).to eq(vm_datastore)
          expect(cdrom_change.device.backing.file_name).to eq('[fake-datastore-name 1] fake-vm-name/env.iso')
        end
      end

      it 'disconnects cdrom, cleans up old env files, uploads environment json, uploads environment iso and connectes cdrom' do
        it_disconnects_cdrom.ordered
        it_cleans_up_old_env_files.ordered
        it_uploads_environment_json.ordered
        it_generates_environment_iso.ordered
        it_uploads_environment_iso.ordered
        it_reconfigures_cdrom.ordered

        agent_env.set_env(vm, location, env)
      end

      context 'when cdrom is disconnected' do
        let(:cdrom_connectable_connected) { false }

        it 'does not disconnect cdrom' do
          it_cleans_up_old_env_files.ordered
          it_uploads_environment_json.ordered
          it_generates_environment_iso(iso_generator: 'genisoimage').ordered
          it_uploads_environment_iso.ordered
          it_reconfigures_cdrom.ordered

          agent_env.set_env(vm, location, env)
        end
      end

      context 'when genisoimage is found' do
        before do
          stub_const('ENV', {'PATH' => '/bin'})
          allow(File).to receive(:exists?).and_call_original
          allow(File).to receive(:exists?).with('/bin/genisoimage').and_return(true)
        end

        it 'uses genisoimage' do
          it_disconnects_cdrom.ordered
          it_cleans_up_old_env_files.ordered
          it_uploads_environment_json.ordered
          it_generates_environment_iso(iso_generator: '/bin/genisoimage').ordered
          it_uploads_environment_iso.ordered
          it_reconfigures_cdrom.ordered

          agent_env.set_env(vm, location, env)
        end
      end

      context 'when genisoimage is not found' do
        before do
          stub_const('ENV', {'PATH' => '/bin'})
          allow(File).to receive(:exists?).and_call_original
          allow(File).to receive(:exists?).with('/bin/mkisofs').and_return(true)
        end

        it 'uses mkisofs' do
          it_disconnects_cdrom.ordered
          it_cleans_up_old_env_files.ordered
          it_uploads_environment_json.ordered
          it_generates_environment_iso(iso_generator: '/bin/mkisofs').ordered
          it_uploads_environment_iso.ordered
          it_reconfigures_cdrom.ordered

          agent_env.set_env(vm, location, env)
        end
      end

      context 'when uploading environment file fails' do
        before { it_uploads_environment_json(500) }

        it 'retries and raises an error' do
          it_disconnects_cdrom.ordered
          it_cleans_up_old_env_files.ordered

          expect {
            agent_env.set_env(vm, location, env)
          }.to raise_error
        end
      end

      context 'when generating iso image fails' do
        before { it_generates_environment_iso(exit_status: 1) }

        it 'raises an error' do
          it_disconnects_cdrom.ordered
          it_cleans_up_old_env_files.ordered
          it_uploads_environment_json.ordered

          expect {
            agent_env.set_env(vm, location, env)
          }.to raise_error
        end
      end

      context 'when the cdrom backing is without file backing' do
        let(:cdrom_backing) do
          VimSdk::Vim::Vm::Device::VirtualCdrom::AtapiBackingInfo.new
        end

        it 'does not clean up the env files' do
          it_disconnects_cdrom.ordered
          it_uploads_environment_json.ordered
          it_generates_environment_iso.ordered
          it_uploads_environment_iso.ordered
          it_reconfigures_cdrom.ordered

          expect(client).not_to receive(:delete_path)

          agent_env.set_env(vm, location, env)
        end
      end
    end

    describe '#env_iso_folder' do
      let(:cdrom) { instance_double('VimSdk::Vim::Vm::Device::VirtualCdrom', backing: cdrom_backing) }
      context 'when the backing has filename' do
        let(:cdrom_backing) do
          VimSdk::Vim::Vm::Device::VirtualCdrom::IsoBackingInfo.new(
            file_name: '[fake-old-datastore-name 1] fake-vm-name/env.iso'
          )
        end

        it 'returns iso parent folder' do
          expect(agent_env.env_iso_folder(cdrom)).to eql('[fake-old-datastore-name 1] fake-vm-name')
        end
      end

      context 'when the backing does not have filename' do
        let(:cdrom_backing) do
          VimSdk::Vim::Vm::Device::VirtualCdrom::AtapiBackingInfo.new
        end

        it 'returns nil' do
          expect(agent_env.env_iso_folder(cdrom)).to be_nil
        end
      end
    end
  end
end
