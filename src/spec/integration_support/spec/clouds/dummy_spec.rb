require 'spec_helper'
require 'stringio'
require 'tempfile'
require 'logging' # loaded by bosh/director in spec_helper; explicit here for clarity
require 'integration_support/clouds/dummy'
require 'integration_support/clouds/dummy_v2'

describe Bosh::Clouds::Dummy do
  let(:tmpdir) { Dir.mktmpdir('dummy_cpi_spec') }

  let(:base_options) do
    {
      'dir' => tmpdir,
      'agent' => {
        'blobstore' => {
          'provider' => 'local',
          'options' => { 'blobstore_path' => File.join(tmpdir, 'blobstore') },
        },
      },
      'nats' => 'nats://127.0.0.1:4222',
      'log_buffer' => StringIO.new,
    }
  end

  subject(:dummy) { described_class.new(base_options, {}, 1) }

  after { FileUtils.rm_rf(tmpdir) }

  before do
    allow(dummy).to receive(:spawn_agent_process).and_return(99999)
    allow(Process).to receive(:kill)
  end

  let(:static_networks) do
    { 'a' => { 'type' => 'manual', 'ip' => '192.168.1.10' } }
  end

  def create_test_vm(agent_id: 'agent-1', networks: static_networks)
    dummy.create_vm(agent_id, 'stemcell-1', {}, networks, [], {})
  end

  def create_test_disk(size: 1024)
    dummy.create_disk(size, {}, 'vm-locality')
  end

  def create_test_stemcell
    image_file = Tempfile.new(['stemcell', '.tgz'], tmpdir)
    image_file.write(YAML.dump('name' => 'test-stemcell', 'version' => '1'))
    image_file.close
    dummy.create_stemcell(image_file.path, {})
  end

  # -----------------------------------------------------------------------
  # Initialization
  # -----------------------------------------------------------------------

  describe '#initialize' do
    it 'creates the base directory' do
      new_dir = File.join(tmpdir, 'new_base')
      described_class.new(base_options.merge('dir' => new_dir), {}, 1)
      expect(File.directory?(new_dir)).to be(true)
    end

    it 'raises ArgumentError when dir is not specified' do
      expect {
        described_class.new(base_options.reject { |k, _| k == 'dir' }, {}, 1)
      }.to raise_error(ArgumentError, /Must specify dir/)
    end

    it 'stores the api_version' do
      cpi = described_class.new(base_options, {}, 2)
      expect(cpi.info['api_version']).to eq(2)
    end

    it 'uses the context formats when provided' do
      cpi = described_class.new(base_options, { 'formats' => ['ubuntu-stemcell'] }, 1)
      expect(cpi.info[:stemcell_formats]).to eq(['ubuntu-stemcell'])
    end

    it 'defaults to dummy stemcell format when context formats not set' do
      expect(dummy.info[:stemcell_formats]).to eq(['dummy'])
    end
  end

  # -----------------------------------------------------------------------
  # #info
  # -----------------------------------------------------------------------

  describe '#info' do
    it 'returns stemcell_formats' do
      expect(dummy.info).to include(stemcell_formats: ['dummy'])
    end

    it 'includes api_version when set' do
      cpi = described_class.new(base_options, {}, 2)
      expect(cpi.info['api_version']).to eq(2)
    end

    it 'omits api_version when nil' do
      cpi = described_class.new(base_options, {}, nil)
      expect(cpi.info.keys).not_to include('api_version')
    end
  end

  # -----------------------------------------------------------------------
  # Stemcell lifecycle
  # -----------------------------------------------------------------------

  describe '#create_stemcell' do
    it 'creates a stemcell and returns a unique ID' do
      stemcell_id = create_test_stemcell
      expect(stemcell_id).to be_a(String)
      expect(stemcell_id).not_to be_empty
    end

    it 'persists stemcell data to disk' do
      stemcell_id = create_test_stemcell
      stemcell_file = File.join(tmpdir, "stemcell_#{stemcell_id}")
      expect(File.exist?(stemcell_file)).to be(true)
    end

    it 'creates two stemcells with unique IDs' do
      id1 = create_test_stemcell
      id2 = create_test_stemcell
      expect(id1).not_to eq(id2)
    end
  end

  describe '#delete_stemcell' do
    it 'removes the stemcell file' do
      stemcell_id = create_test_stemcell
      dummy.delete_stemcell(stemcell_id)
      stemcell_file = File.join(tmpdir, "stemcell_#{stemcell_id}")
      expect(File.exist?(stemcell_file)).to be(false)
    end
  end

  describe '#all_stemcells' do
    it 'returns all created stemcells' do
      create_test_stemcell
      create_test_stemcell
      expect(dummy.all_stemcells.size).to eq(2)
    end

    it 'returns empty when no stemcells exist' do
      expect(dummy.all_stemcells).to be_empty
    end
  end

  # -----------------------------------------------------------------------
  # VM lifecycle
  # -----------------------------------------------------------------------

  describe '#create_vm' do
    it 'returns a VM cid string' do
      vm_cid = create_test_vm
      expect(vm_cid).to be_a(String)
      expect(vm_cid).not_to be_empty
    end

    it 'spawns an agent process' do
      expect(dummy).to receive(:spawn_agent_process).and_return(99999)
      create_test_vm
    end

    it 'allocates the static IP address' do
      create_test_vm(networks: { 'a' => { 'type' => 'manual', 'ip' => '10.0.0.1' } })
      expect(dummy.all_ips).to include('10.0.0.1')
    end

    it 'raises CloudError when create_vm is configured to fail' do
      dummy.commands.make_create_vm_always_fail
      expect {
        create_test_vm
      }.to raise_error(Bosh::Clouds::CloudError, /Creating vm failed/)
    end

    it 'raises when the same static IP is allocated twice' do
      create_test_vm(agent_id: 'agent-1', networks: static_networks)
      expect {
        create_test_vm(agent_id: 'agent-2', networks: static_networks)
      }.to raise_error(RuntimeError, /IP Address 192.168.1.10 in network 'a' is already in use/)
    end

    it 'writes agent settings to disk' do
      vm_cid = create_test_vm(agent_id: 'my-agent')
      agent_settings_file = File.join(tmpdir, 'agent-base-dir-my-agent', 'bosh', 'dummy-cpi-agent-env.json')
      expect(File.exist?(agent_settings_file)).to be(true)
      settings = JSON.parse(File.read(agent_settings_file))
      expect(settings['agent_id']).to eq('my-agent')
    end
  end

  describe '#has_vm' do
    it 'returns true for an existing VM' do
      vm_cid = create_test_vm
      expect(dummy.has_vm(vm_cid)).to be(true)
    end

    it 'returns false for a non-existent VM' do
      expect(dummy.has_vm('nonexistent-cid')).to be(false)
    end
  end

  describe '#delete_vm' do
    it 'removes the VM' do
      vm_cid = create_test_vm
      dummy.delete_vm(vm_cid)
      expect(dummy.has_vm(vm_cid)).to be(false)
    end

    it 'frees the allocated IPs' do
      vm_cid = create_test_vm(networks: { 'a' => { 'type' => 'manual', 'ip' => '10.0.0.2' } })
      dummy.delete_vm(vm_cid)
      expect(dummy.all_ips).not_to include('10.0.0.2')
    end

    it 'raises VMNotFound when configured to do so' do
      dummy.commands.make_delete_vm_to_raise_vmnotfound
      vm_cid = create_test_vm
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      expect {
        dummy.delete_vm(vm_cid)
      }.to raise_error(Bosh::Clouds::VMNotFound)
    end
  end

  describe '#vm_cids' do
    it 'returns all current VM cids' do
      # Return distinct PIDs so each VM gets its own unique cid (vm_cid == agent_pid.to_s)
      allow(dummy).to receive(:spawn_agent_process).and_return(10001, 10002)
      vm1 = create_test_vm(agent_id: 'agent-a', networks: { 'net' => { 'type' => 'manual', 'ip' => '10.0.0.1' } })
      vm2 = create_test_vm(agent_id: 'agent-b', networks: { 'net' => { 'type' => 'manual', 'ip' => '10.0.0.2' } })
      expect(dummy.vm_cids).to contain_exactly(vm1, vm2)
    end

    it 'returns empty when no VMs exist' do
      expect(dummy.vm_cids).to be_empty
    end
  end

  describe '#reboot_vm' do
    it 'raises NotImplemented' do
      expect {
        dummy.reboot_vm('some-vm-cid')
      }.to raise_error(Bosh::Clouds::Dummy::NotImplemented, /does not implement reboot_vm/)
    end
  end

  # -----------------------------------------------------------------------
  # Disk lifecycle
  # -----------------------------------------------------------------------

  describe '#create_disk' do
    it 'returns a disk id' do
      disk_id = create_test_disk
      expect(disk_id).to be_a(String)
      expect(disk_id).not_to be_empty
    end

    it 'persists the disk file' do
      disk_id = create_test_disk
      expect(File.exist?(File.join(tmpdir, 'disks', disk_id))).to be(true)
    end

    it 'stores the disk size in the file' do
      disk_id = create_test_disk(size: 2048)
      disk_info = JSON.parse(File.read(File.join(tmpdir, 'disks', disk_id)))
      expect(disk_info['size']).to eq(2048)
    end
  end

  describe '#has_disk' do
    it 'returns true for an existing disk' do
      disk_id = create_test_disk
      expect(dummy.has_disk(disk_id)).to be(true)
    end

    it 'returns false for a non-existent disk' do
      expect(dummy.has_disk('nonexistent-disk')).to be(false)
    end
  end

  describe '#delete_disk' do
    it 'removes the disk' do
      disk_id = create_test_disk
      dummy.delete_disk(disk_id)
      expect(dummy.has_disk(disk_id)).to be(false)
    end
  end

  describe '#disk_cids' do
    it 'returns all created disk ids' do
      id1 = create_test_disk
      id2 = create_test_disk
      expect(dummy.disk_cids).to contain_exactly(id1, id2)
    end
  end

  # -----------------------------------------------------------------------
  # Disk attachment
  # -----------------------------------------------------------------------

  describe '#attach_disk' do
    let(:vm_cid) { create_test_vm }
    let(:disk_id) { create_test_disk }

    it 'attaches a disk to a VM' do
      dummy.attach_disk(vm_cid, disk_id)
      expect(dummy.disk_attached_to_vm?(vm_cid, disk_id)).to be(true)
    end

    it 'records the disk in agent settings' do
      dummy.attach_disk(vm_cid, disk_id)
      infos = dummy.attached_disk_infos(vm_cid)
      expect(infos.map { |i| i['disk_cid'] }).to include(disk_id)
    end

    it 'raises when disk is already attached' do
      dummy.attach_disk(vm_cid, disk_id)
      expect {
        dummy.attach_disk(vm_cid, disk_id)
      }.to raise_error(RuntimeError, /already attached/)
    end

    it 'raises NotImplemented when configured to do so' do
      dummy.commands.make_attach_disk_to_raise_not_implemented
      expect {
        dummy.attach_disk(vm_cid, disk_id)
      }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe '#detach_disk' do
    let(:vm_cid) { create_test_vm }
    let(:disk_id) { create_test_disk }

    before { dummy.attach_disk(vm_cid, disk_id) }

    it 'detaches a disk from a VM' do
      dummy.detach_disk(vm_cid, disk_id)
      expect(dummy.disk_attached_to_vm?(vm_cid, disk_id)).to be(false)
    end

    it 'removes the disk from agent settings' do
      dummy.detach_disk(vm_cid, disk_id)
      infos = dummy.attached_disk_infos(vm_cid)
      expect(infos.map { |i| i['disk_cid'] }).not_to include(disk_id)
    end

    it 'raises DiskNotAttached when disk is not attached' do
      dummy.detach_disk(vm_cid, disk_id)
      expect {
        dummy.detach_disk(vm_cid, disk_id)
      }.to raise_error(Bosh::Clouds::DiskNotAttached)
    end

    it 'raises NotImplemented when configured to do so' do
      dummy.commands.make_detach_disk_to_raise_not_implemented
      expect {
        dummy.detach_disk(vm_cid, disk_id)
      }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  # -----------------------------------------------------------------------
  # Disk resize / update
  # -----------------------------------------------------------------------

  describe '#resize_disk' do
    let(:disk_id) { create_test_disk(size: 1024) }

    it 'updates the disk size' do
      dummy.resize_disk(disk_id, 2048)
      disk_info = JSON.parse(File.read(File.join(tmpdir, 'disks', disk_id)))
      expect(disk_info['size']).to eq(2048)
    end

    it 'raises NotImplemented when configured to do so' do
      dummy.commands.make_resize_disk_to_raise_not_implemented
      expect {
        dummy.resize_disk(disk_id, 2048)
      }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe '#update_disk' do
    let(:disk_id) { create_test_disk(size: 1024) }

    it 'updates the disk size and cloud properties' do
      dummy.update_disk(disk_id, 4096, { 'type' => 'ssd' })
      disk_info = JSON.parse(File.read(File.join(tmpdir, 'disks', disk_id)))
      expect(disk_info['size']).to eq(4096)
      expect(disk_info['cloud_properties']).to eq('type' => 'ssd')
    end

    it 'raises NotImplemented when configured to do so' do
      dummy.commands.make_update_disk_to_raise_not_implemented
      expect {
        dummy.update_disk(disk_id, 4096, {})
      }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  # -----------------------------------------------------------------------
  # Snapshot lifecycle
  # -----------------------------------------------------------------------

  describe '#snapshot_disk' do
    let(:disk_id) { create_test_disk }

    it 'returns a snapshot id' do
      snapshot_id = dummy.snapshot_disk(disk_id, { 'env' => 'test' })
      expect(snapshot_id).to be_a(String)
      expect(snapshot_id).not_to be_empty
    end

    it 'persists snapshot metadata' do
      snapshot_id = dummy.snapshot_disk(disk_id, { 'label' => 'backup' })
      expect(dummy.all_snapshots.size).to eq(1)
      snapshot_file = dummy.all_snapshots.first
      metadata = JSON.parse(File.read(snapshot_file))
      expect(metadata['label']).to eq('backup')
    end
  end

  describe '#delete_snapshot' do
    let(:disk_id) { create_test_disk }

    it 'removes the snapshot' do
      snapshot_id = dummy.snapshot_disk(disk_id, {})
      dummy.delete_snapshot(snapshot_id)
      expect(dummy.all_snapshots).to be_empty
    end
  end

  # -----------------------------------------------------------------------
  # Network lifecycle
  # -----------------------------------------------------------------------

  describe '#create_network' do
    it 'returns [network_id, addr_properties, tags]' do
      result = dummy.create_network({ 'cloud_properties' => {} })
      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result[0]).to be_a(String)
    end

    it 'includes range/gateway when netmask_bits is specified' do
      _, addr_props, _ = dummy.create_network({ 'cloud_properties' => {}, 'netmask_bits' => 24 })
      expect(addr_props['range']).not_to be_nil
      expect(addr_props['gateway']).not_to be_nil
    end

    it 'raises when cloud_properties includes an error key' do
      expect {
        dummy.create_network({ 'cloud_properties' => { 'error' => 'something went wrong' } })
      }.to raise_error('something went wrong')
    end
  end

  describe '#delete_network' do
    it 'removes the network' do
      network_id, _, _ = dummy.create_network({ 'cloud_properties' => {} })
      dummy.delete_network(network_id)
      expect(dummy.network_cids).not_to include(network_id)
    end
  end

  # -----------------------------------------------------------------------
  # Metadata
  # -----------------------------------------------------------------------

  describe '#set_vm_metadata' do
    let(:vm_cid) { create_test_vm }

    it 'succeeds normally' do
      expect { dummy.set_vm_metadata(vm_cid, { 'tag' => 'value' }) }.not_to raise_error
    end

    it 'raises when configured to fail' do
      dummy.commands.make_set_vm_metadata_always_fail
      expect {
        dummy.set_vm_metadata(vm_cid, {})
      }.to raise_error(RuntimeError, /Set VM metadata failed/)
    end
  end

  describe '#set_disk_metadata' do
    let(:disk_id) { create_test_disk }

    it 'succeeds without errors' do
      expect { dummy.set_disk_metadata(disk_id, { 'key' => 'val' }) }.not_to raise_error
    end
  end

  # -----------------------------------------------------------------------
  # calculate_vm_cloud_properties
  # -----------------------------------------------------------------------

  describe '#calculate_vm_cloud_properties' do
    it 'returns a cloud properties hash with instance_type' do
      result = dummy.calculate_vm_cloud_properties({ 'ram' => 1024, 'cpu' => 2, 'ephemeral_disk_size' => 10 })
      expect(result[:instance_type]).to eq('dummy')
      expect(result[:cpu]).to eq(2)
      expect(result[:ram]).to eq(1024)
      expect(result.dig(:ephemeral_disk, :size)).to eq(10)
    end

    it 'uses cvcpkey from context when present' do
      cpi = described_class.new(base_options, { 'cvcpkey' => 'xlarge' }, 1)
      result = cpi.calculate_vm_cloud_properties({ 'ram' => 2048, 'cpu' => 4, 'ephemeral_disk_size' => 20 })
      expect(result[:instance_type]).to eq('xlarge')
    end
  end

  # -----------------------------------------------------------------------
  # Invocations recording
  # -----------------------------------------------------------------------

  describe '#invocations' do
    it 'records CPI method invocations' do
      create_test_disk
      invocations = dummy.invocations
      # method_name is stored via JSON, so it comes back as a String
      expect(invocations.map(&:method_name)).to include('create_disk')
    end

    it 'records multiple different method invocations' do
      create_test_disk
      create_test_vm
      methods_called = dummy.invocations.map(&:method_name)
      expect(methods_called).to include('create_disk', 'create_vm')
    end
  end

  describe '#invocations_for_method' do
    it 'returns only invocations for the specified method' do
      create_test_disk
      create_test_vm
      # method_name is stored as a String after JSON round-trip
      create_disk_invocations = dummy.invocations_for_method('create_disk')
      expect(create_disk_invocations.size).to eq(1)
      expect(create_disk_invocations.first.method_name).to eq('create_disk')
    end
  end

  # -----------------------------------------------------------------------
  # kill_agents / reset
  # -----------------------------------------------------------------------

  describe '#kill_agents' do
    it 'kills all running VMs without error' do
      create_test_vm(agent_id: 'agent-a', networks: { 'net' => { 'type' => 'manual', 'ip' => '10.0.0.1' } })
      expect { dummy.kill_agents }.not_to raise_error
    end
  end

  describe '#reset' do
    it 'removes and recreates the base directory' do
      create_test_disk
      dummy.reset
      expect(dummy.disk_cids).to be_empty
    end
  end

  # -----------------------------------------------------------------------
  # CommandTransport
  # -----------------------------------------------------------------------

  describe 'CommandTransport' do
    subject(:commands) { dummy.commands }

    describe 'create_vm commands' do
      it 'defaults to a non-failing create_vm' do
        expect(commands.next_create_vm_cmd.failed?).to be(false)
      end

      it 'makes create_vm always fail when configured' do
        commands.make_create_vm_always_fail
        expect(commands.next_create_vm_cmd.failed?).to be(true)
      end

      it 'allows create_vm to succeed again after failure was set' do
        commands.make_create_vm_always_fail
        commands.allow_create_vm_to_succeed
        expect(commands.next_create_vm_cmd.failed?).to be(false)
      end

      it 'sets a dynamic IP address for all AZs' do
        commands.make_create_vm_always_use_dynamic_ip('1.2.3.4')
        expect(commands.next_create_vm_cmd.ip_address).to eq('1.2.3.4')
      end

      it 'sets az-specific IP addresses' do
        commands.set_dynamic_ips_for_azs('us-east-1a' => '10.0.1.5')
        cmd = commands.next_create_vm_cmd
        expect(cmd.ip_address_for_az('us-east-1a')).to eq('10.0.1.5')
        expect(cmd.ip_address_for_az('us-west-2b')).to be_nil
      end
    end

    describe 'set_vm_metadata commands' do
      it 'defaults to not failing' do
        expect(commands.set_vm_metadata_should_fail?).to be(false)
      end

      it 'can be configured to fail' do
        commands.make_set_vm_metadata_always_fail
        expect(commands.set_vm_metadata_should_fail?).to be(true)
      end
    end

    describe 'delete_vm commands' do
      it 'defaults to not raising VMNotFound' do
        expect(commands.raise_vmnotfound).to be(false)
      end

      it 'can be configured to raise VMNotFound' do
        commands.make_delete_vm_to_raise_vmnotfound
        expect(commands.raise_vmnotfound).to be(true)
      end
    end

    describe 'attach_disk commands' do
      it 'defaults to not raising NotImplemented' do
        expect(commands.raise_attach_disk_not_implemented).to be(false)
      end

      it 'can be configured to raise NotImplemented' do
        commands.make_attach_disk_to_raise_not_implemented
        expect(commands.raise_attach_disk_not_implemented).to be(true)
      end
    end
  end
end

describe Bosh::Clouds::DummyV2 do
  let(:tmpdir) { Dir.mktmpdir('dummy_v2_cpi_spec') }

  let(:base_options) do
    {
      'dir' => tmpdir,
      'agent' => {
        'blobstore' => {
          'provider' => 'local',
          'options' => { 'blobstore_path' => File.join(tmpdir, 'blobstore') },
        },
      },
      'nats' => 'nats://127.0.0.1:4222',
      'log_buffer' => StringIO.new,
    }
  end

  subject(:dummy_v2) { described_class.new(base_options, {}) }

  after { FileUtils.rm_rf(tmpdir) }

  before do
    allow(dummy_v2).to receive(:spawn_agent_process).and_return(99998)
    allow(Process).to receive(:kill)
  end

  describe '#info' do
    it 'returns api_version 2' do
      expect(dummy_v2.info[:api_version]).to eq(2)
    end

    it 'returns stemcell_formats' do
      expect(dummy_v2.info).to include(stemcell_formats: ['dummy'])
    end
  end

  describe '#create_vm' do
    it 'returns [vm_cid, network_settings] tuple' do
      result = dummy_v2.create_vm('agent-1', 'stem-1', {}, { 'a' => { 'type' => 'manual', 'ip' => '10.0.0.1' } }, [], {})
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      vm_cid, network_settings = result
      expect(vm_cid).to be_a(String)
      expect(network_settings).to eq({})
    end
  end

  describe '#attach_disk' do
    it 'returns the attachment file path' do
      vm_cid, _ = dummy_v2.create_vm('agent-1', 'stem-1', {}, { 'a' => { 'type' => 'manual', 'ip' => '10.0.0.1' } }, [], {})
      disk_id = dummy_v2.create_disk(1024, {}, 'vm-locality')

      result = dummy_v2.attach_disk(vm_cid, disk_id)
      expect(result).to be_a(String)
      expect(File.exist?(result)).to be(true)
    end
  end
end
