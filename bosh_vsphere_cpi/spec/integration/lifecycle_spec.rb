require 'spec_helper'
require 'bosh/cpi/compatibility_helpers/delete_vm'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud, external_cpi: false do
  before(:all) do
    @host = ENV.fetch('BOSH_VSPHERE_CPI_HOST')
    @user = ENV.fetch('BOSH_VSPHERE_CPI_USER')
    @password = ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD')
    @vlan = ENV.fetch('BOSH_VSPHERE_VLAN')
    @stemcell_path = ENV.fetch('BOSH_VSPHERE_STEMCELL')

    @second_datastore = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_DATASTORE')

    @datacenter_name = ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER')
    @vm_folder = ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER')
    @template_folder = ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER')
    @disk_path = ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH')
    @datastore_pattern = ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN')
    @persistent_datastore_pattern = ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN')
    @cluster = ENV.fetch('BOSH_VSPHERE_CPI_CLUSTER')
    @resource_pool_name = ENV.fetch('BOSH_VSPHERE_CPI_RESOURCE_POOL')

    @second_cluster = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_CLUSTER')
    @second_cluster_resource_pool_name = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_RESOURCE_POOL')
    @second_cluster_ephemeral_datastore_pattern = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_DATASTORE_PATTERN')
    @second_cluster_persistent_datastore_pattern = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_PERSISTENT_DATASTORE_PATTERN')
  end

  def build_cpi(options = {})
    datastore_pattern = options.fetch(:datastore_pattern, @datastore_pattern)
    persistent_datastore_pattern = options.fetch(:persistent_datastore_pattern, @persistent_datastore_pattern)
    default_clusters = [
      { @cluster => {'resource_pool' => @resource_pool_name} },
      { @second_cluster => {'resource_pool' => @second_cluster_resource_pool_name } },
    ]
    clusters = options.fetch(:clusters, default_clusters)

    described_class.new(
      'agent' => {
        'ntp' => ['10.80.0.44'],
      },
      'vcenters' => [{
          'host' => @host,
          'user' => @user,
          'password' => @password,
          'datacenters' => [{
              'name' => @datacenter_name,
              'vm_folder' => @vm_folder,
              'template_folder' => @template_folder,
              'disk_path' => @disk_path,
              'datastore_pattern' => datastore_pattern,
              'persistent_datastore_pattern' => persistent_datastore_pattern,
              'allow_mixed_datastores' => true,
              'clusters' => clusters,
            }]
        }]
    )
  end

  before(:all) { @cpi = build_cpi }

  subject(:cpi) { @cpi }

  before(:all) do
    Dir.mktmpdir do |temp_dir|
      output = `tar -C #{temp_dir} -xzf #{@stemcell_path} 2>&1`
      raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0
      @stemcell_id = @cpi.create_stemcell("#{temp_dir}/image", nil)
    end
  end

  after(:all) { @cpi.delete_stemcell(@stemcell_id) if @stemcell_id }

  extend Bosh::Cpi::CompatibilityHelpers
  it_can_delete_non_existent_vm

  def network_spec
    {
      'static' => {
        'ip' => '169.254.1.1',
        'netmask' => '255.255.254.0',
        'cloud_properties' => {'name' => @vlan},
        'default' => ['dns', 'gateway'],
        'dns' => ['169.254.1.2'],
        'gateway' => '169.254.1.3'
      }
    }
  end

  def vm_lifecycle(disk_locality, resource_pool)
    @vm_id = @cpi.create_vm(
      'agent-007',
      @stemcell_id,
      resource_pool,
      network_spec,
      disk_locality,
      {'key' => 'value'}
    )

    expect(@vm_id).to_not be_nil
    expect(@cpi.has_vm?(@vm_id)).to be(true)

    yield if block_given?

    metadata = {deployment: 'deployment', job: 'cpi_spec', index: '0'}
    @cpi.set_vm_metadata(@vm_id, metadata)

    @disk_id = @cpi.create_disk(2048, {}, @vm_id)
    expect(@disk_id).to_not be_nil

    @cpi.attach_disk(@vm_id, @disk_id)
    expect(@cpi.has_disk?(@disk_id)).to be(true)

    network_spec['static']['ip'] = '169.254.1.2'

    @cpi.configure_networks(@vm_id, network_spec)

    metadata[:bosh_data] = 'bosh data'
    metadata[:instance_id] = 'instance'
    metadata[:agent_id] = 'agent'
    metadata[:director_name] = 'Director'
    metadata[:director_uuid] = '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'

    expect {
      @cpi.snapshot_disk(@disk_id, metadata)
    }.to raise_error Bosh::Clouds::NotImplemented

    expect {
      @cpi.delete_snapshot(123)
    }.to raise_error Bosh::Clouds::NotImplemented

    @cpi.detach_disk(@vm_id, @disk_id)
  end

  let(:resource_pool) {
    {
      'ram' => 1024,
      'disk' => 2048,
      'cpu' => 1,
    }
  }

  def clean_up_vm_and_disk
    @cpi.delete_vm(@vm_id) if @vm_id
    @vm_id = nil
    @cpi.delete_disk(@disk_id) if @disk_id
    @disk_id = nil
  end

  describe 'lifecycle' do
    before { @vm_id = nil }
    before { @disk_id = nil }
    after { clean_up_vm_and_disk }

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle([], resource_pool)
      end
    end

    context 'without existing disks and placer' do
      it 'should exercise the vm lifecycle and select the cluster in the resource pool datacenters' do
        begin
          resource_pool['datacenters'] = [{'name' => @datacenter_name, 'clusters' => [{@cluster => {}}]}]
          vm_lifecycle([], resource_pool)

          vm = @cpi.vm_provider.find(@vm_id)
          expect(vm.cluster).to eq(@cluster)
        ensure
          clean_up_vm_and_disk
        end

        begin
          @cpi = build_cpi(datastore_pattern: @second_cluster_ephemeral_datastore_pattern, persistent_datastore_pattern: @second_cluster_persistent_datastore_pattern)

          resource_pool['datacenters'] = [{'name' => @datacenter_name, 'clusters' => [{@second_cluster => {}}]}]
          vm_lifecycle([], resource_pool)

          vm = @cpi.vm_provider.find(@vm_id)
          expect(vm.cluster).to eq(@second_cluster)
        ensure
          clean_up_vm_and_disk
        end
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = @cpi.create_disk(2048, {}) }
      after { @cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'should exercise the vm lifecycle' do
        vm_lifecycle([@existing_volume_id], resource_pool)
      end
    end
  end

  describe 'vsphere specific lifecycle' do
    context 'when datacenter is in folder' do
      let(:client) do
        VSphereCloud::Client.new("https://#{@host}/sdk/vimService").tap do |client|
          client.login(@user, @password, 'en')
        end
      end

      let(:datacenter) { client.find_by_inventory_path(@datacenter_name) }
      let(:folder_name) { SecureRandom.uuid }
      let(:folder) { client.create_folder(folder_name) }

      before do
        client.move_into_folder(folder, [datacenter])
        @old_datacenter_name = @datacenter_name
        @datacenter_name = "#{folder_name}/#{@datacenter_name}"
        @cpi = build_cpi

        @vm_id = nil
        @disk_id = nil
      end

      after do
        clean_up_vm_and_disk

        client.move_into_root_folder([datacenter])
        @datacenter_name = @old_datacenter_name
        @old_datacenter_name = nil
        @cpi = build_cpi
        client.delete_folder(folder)
      end

      it 'exercises the vm lifecycle' do
        vm_lifecycle([], resource_pool)
      end
    end

    context 'when disk is being re-attached' do
      after { clean_up_vm_and_disk }

      it 'does not lock cd-rom' do
        vm_lifecycle([], resource_pool)
        @cpi.attach_disk(@vm_id, @disk_id)
        @cpi.detach_disk(@vm_id, @disk_id)
      end
    end

    context 'when vm was migrated' do
      after { clean_up_vm_and_disk }

      def relocate_vm_to_second_datastore
        vm = @cpi.vm_provider.find(@vm_id)

        datastore = @cpi.client.cloud_searcher.get_managed_object(VimSdk::Vim::Datastore, name: @second_datastore)
        relocate_spec = VimSdk::Vim::Vm::RelocateSpec.new(datastore: datastore)

        task = vm.mob.relocate(relocate_spec, 'defaultPriority')
        @cpi.client.wait_for_task(task)
      end

      it 'should exercise the vm lifecycle' do
        vm_lifecycle([], resource_pool) do
          relocate_vm_to_second_datastore
        end
      end
    end

    context 'when disk is in non-accessible datastore' do
      after { clean_up_vm_and_disk }

      def find_disk_in_datastore(disk_id, datastore_name)
        datastore_mob = @cpi.client.cloud_searcher.get_managed_object(VimSdk::Vim::Datastore, name: datastore_name)
        datastore = VSphereCloud::Resources::Datastore.new(datastore_name, datastore_mob, 0, 0)
        @cpi.client.find_disk(disk_id, datastore, @disk_path)
      end

      it 'migrates disk to accessible datastore' do
        # verify second datastore is not accessible to cluster
        cluster = @cpi.client.cloud_searcher.get_managed_object(VimSdk::Vim::ClusterComputeResource, name: @cluster)
        expect(cluster.host.size).to eq(1)
        host = cluster.host.first
        accessible_datastores = host.datastore.map(&:name)
        expect(accessible_datastores).to_not include(@second_datastore)

        # create vm in first cluster only
        cpi_for_vm = build_cpi(clusters: [{ @cluster => {'resource_pool' => @resource_pool_name} }])
        @vm_id = cpi_for_vm.create_vm(
          'agent-007',
          @stemcell_id,
          resource_pool,
          network_spec,
          [],
          {}
        )
        expect(@vm_id).to_not be_nil

        # verify disk is created in second datastore
        cpi_for_non_accessible_datastore = build_cpi(
          datastore_pattern: @second_cluster_ephemeral_datastore_pattern,
          persistent_datastore_pattern: @second_cluster_persistent_datastore_pattern,
        )
        @disk_id = cpi_for_non_accessible_datastore.create_disk(128, {}, nil)
        disk = find_disk_in_datastore(@disk_id, @second_datastore)
        expect(disk).to_not be_nil

        @cpi.attach_disk(@vm_id, @disk_id)

        # verify disk is in datastore accessible to vm
        disk_is_in_accessible_datastore = false
        accessible_datastores.each do |datastore_name|
          disk = find_disk_in_datastore(@disk_id, datastore_name)
          unless disk.nil?
            disk_is_in_accessible_datastore = true
            break
          end
        end
        expect(disk_is_in_accessible_datastore).to eq(true)
      end
    end
  end
end
