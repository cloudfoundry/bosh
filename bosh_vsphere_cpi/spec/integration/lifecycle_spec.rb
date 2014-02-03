require 'spec_helper'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud do
  before(:all) do
    @host          = ENV['BOSH_VSPHERE_CPI_HOST']     || raise("Missing BOSH_VSPHERE_CPI_HOST")
    @user          = ENV['BOSH_VSPHERE_CPI_USER']     || raise("Missing BOSH_VSPHERE_CPI_USER")
    @password      = ENV['BOSH_VSPHERE_CPI_PASSWORD'] || raise("Missing BOSH_VSPHERE_CPI_PASSWORD")
    @vlan          = ENV['BOSH_VSPHERE_VLAN']         || raise("Missing BOSH_VSPHERE_VLAN")
    @stemcell_path = ENV['BOSH_VSPHERE_STEMCELL']     || raise("Missing BOSH_VSPHERE_STEMCELL")
  end

  before(:all) do
    @cpi = described_class.new(
      "agent" => {
        "ntp" => ["10.80.0.44"],
      },
      "vcenters" => [{
        "host" => @host,
        "user" => @user,
        "password" => @password,
        "datacenters" => [{
          "name" => "BOSH_DC",
          "vm_folder" => "ACCEPTANCE_BOSH_VMs",
          "template_folder" => "ACCEPTANCE_BOSH_Templates",
          "disk_path" => "ACCEPTANCE_BOSH_Disks",
          "datastore_pattern" => "jalapeno",
          "persistent_datastore_pattern" => "jalapeno",
          "allow_mixed_datastores" => true,
          "clusters" => [{
            "BOSH_CL" => {"resource_pool" => "ACCEPTANCE_RP"}
          }]
        }]
      }]
    )
  end

  let(:cpi) { @cpi }

  before(:all) do
    Dir.mktmpdir do |temp_dir|
      output = `tar -C #{temp_dir} -xzf #{@stemcell_path} 2>&1`
      raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0
      @stemcell_id = @cpi.create_stemcell("#{temp_dir}/image", nil)
    end
  end

  after(:all) { @cpi.delete_stemcell(@stemcell_id) if @stemcell_id }

  before { @vm_id = nil }
  after { cpi.delete_vm(@vm_id) if @vm_id }

  before { @disk_id = nil }
  after { cpi.delete_disk(@disk_id) if @disk_id }

  def vm_lifecycle(network_spec, disk_locality)
    resource_pool = {
      'ram' => 1024,
      'disk' => 2048,
      'cpu' => 1,
    }

    @vm_id = cpi.create_vm(
      'agent-007',
      @stemcell_id,
      resource_pool,
      network_spec,
      disk_locality,
      {'key' => 'value'}
    )

    @vm_id.should_not be_nil
    cpi.has_vm?(@vm_id).should be(true)

    metadata = {deployment: 'deployment', job: 'cpi_spec', index: '0'}
    cpi.set_vm_metadata(@vm_id, metadata)

    @disk_id = cpi.create_disk(2048, @vm_id)
    @disk_id.should_not be_nil

    cpi.attach_disk(@vm_id, @disk_id)

    metadata[:bosh_data] = 'bosh data'
    metadata[:instance_id] = 'instance'
    metadata[:agent_id] = 'agent'
    metadata[:director_name] = 'Director'
    metadata[:director_uuid] = '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'

    expect {
      cpi.snapshot_disk(@disk_id, metadata)
    }.to raise_error Bosh::Clouds::NotImplemented

    yield if block_given?

    expect {
      cpi.delete_snapshot(123)
    }.to raise_error Bosh::Clouds::NotImplemented

    cpi.detach_disk(@vm_id, @disk_id)
  end

  describe 'vsphere' do
    let(:network_spec) do
      {
        "static" => {
          "ip" => "169.254.1.1", #172.16.69.102",
          "netmask" => "255.255.254.0",
          "cloud_properties" => {"name" => @vlan},
          "default" => ["dns", "gateway"],
          "dns" => ["169.254.1.2"],  #["172.16.69.100"],
          "gateway" => "169.254.1.3" #"172.16.68.1"
        }
      }
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle(network_spec, [])
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'should exercise the vm lifecycle' do
        vm_lifecycle(network_spec, [@existing_volume_id])
      end
    end
  end
end
