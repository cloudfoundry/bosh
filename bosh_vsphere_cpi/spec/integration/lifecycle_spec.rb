require 'spec_helper'
require 'bosh/cpi/compatibility_helpers/delete_vm'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud, external_cpi: false do
  before(:all) do
    @host          = ENV['BOSH_VSPHERE_CPI_HOST']     || raise('Missing BOSH_VSPHERE_CPI_HOST')
    @user          = ENV['BOSH_VSPHERE_CPI_USER']     || raise('Missing BOSH_VSPHERE_CPI_USER')
    @password      = ENV['BOSH_VSPHERE_CPI_PASSWORD'] || raise('Missing BOSH_VSPHERE_CPI_PASSWORD')
    @vlan          = ENV['BOSH_VSPHERE_VLAN']         || raise('Missing BOSH_VSPHERE_VLAN')
    @stemcell_path = ENV['BOSH_VSPHERE_STEMCELL']     || raise('Missing BOSH_VSPHERE_STEMCELL')

    @datacenter_name              = ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC')
    @vm_folder                    = ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER', 'ACCEPTANCE_BOSH_VMs')
    @template_folder              = ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER', 'ACCEPTANCE_BOSH_Templates')
    @disk_path                    = ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH', 'ACCEPTANCE_BOSH_Disks')
    @datastore_pattern            = ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN', 'jalapeno')
    @persistent_datastore_pattern = ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN', 'jalapeno')
    @cluster                      = ENV.fetch('BOSH_VSPHERE_CPI_CLUSTER', 'BOSH_CL')
    @resource_pool_name           = ENV.fetch('BOSH_VSPHERE_CPI_RESOURCE_POOL', 'ACCEPTANCE_RP')
    @second_cluster               = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_CLUSTER', 'BOSH_CL2')
    @second_resource_pool_name    = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_RESOURCE_POOL', 'ACCEPTANCE_RP')
  end

  def build_cpi
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
          'datastore_pattern' => @datastore_pattern,
          'persistent_datastore_pattern' => @persistent_datastore_pattern,
          'allow_mixed_datastores' => true,
          'clusters' => [{
              @cluster => { 'resource_pool' => @resource_pool_name },
            },
            {
              @second_cluster  => { 'resource_pool' => @second_resource_pool_name }
            }],
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

  def vm_lifecycle(network_spec, disk_locality, resource_pool)
    @vm_id = @cpi.create_vm(
      'agent-007',
      @stemcell_id,
      resource_pool,
      network_spec,
      disk_locality,
      {'key' => 'value'}
    )

    @vm_id.should_not be_nil
    @cpi.has_vm?(@vm_id).should be(true)

    metadata = {deployment: 'deployment', job: 'cpi_spec', index: '0'}
    @cpi.set_vm_metadata(@vm_id, metadata)

    @disk_id = @cpi.create_disk(2048, @vm_id)
    @disk_id.should_not be_nil

    @cpi.attach_disk(@vm_id, @disk_id)

    metadata[:bosh_data] = 'bosh data'
    metadata[:instance_id] = 'instance'
    metadata[:agent_id] = 'agent'
    metadata[:director_name] = 'Director'
    metadata[:director_uuid] = '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'

    expect {
      @cpi.snapshot_disk(@disk_id, metadata)
    }.to raise_error Bosh::Clouds::NotImplemented

    yield if block_given?

    expect {
      @cpi.delete_snapshot(123)
    }.to raise_error Bosh::Clouds::NotImplemented

    @cpi.detach_disk(@vm_id, @disk_id)
  end

  let(:network_spec) do
    {
      'static' => {
        'ip' => '169.254.1.1', #172.16.69.102",
        'netmask' => '255.255.254.0',
        'cloud_properties' => { 'name' => @vlan},
        'default' => ['dns', 'gateway'],
        'dns' => ['169.254.1.2'],  #["172.16.69.100"],
        'gateway' => '169.254.1.3' #"172.16.68.1"
      }
    }
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
        vm_lifecycle(network_spec, [], resource_pool)
      end
    end

    context 'without existing disks and placer' do
      it 'should exercise the vm lifecycle and select the cluster in the resource pool datacenters' do
        clusters = [{ @cluster => {}, }, { @second_cluster => {} }]

        clusters.each do |cluster|
          begin
            resource_pool['datacenters'] = [{ 'name' => @datacenter_name, 'clusters' => [cluster]}]
            vm_lifecycle(network_spec, [], resource_pool)

            vm = @cpi.get_vm_by_cid(@vm_id)
            vm_info = @cpi.get_vm_host_info(vm)
            expect(vm_info['cluster']).to eq(cluster.keys.first)
          ensure
            clean_up_vm_and_disk
          end
        end
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = @cpi.create_disk(2048) }
      after { @cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'should exercise the vm lifecycle' do
        vm_lifecycle(network_spec, [@existing_volume_id], resource_pool)
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
        vm_lifecycle(network_spec, [], resource_pool)
      end
    end
  end
end
