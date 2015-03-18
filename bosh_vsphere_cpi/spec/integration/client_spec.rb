require 'spec_helper'

describe VSphereCloud::Client do
  describe "#find_disk" do
    it "returns the disk if it exists" do
      disk_cid = "disk-#{SecureRandom.uuid}"

      client, datacenter, datastore, disk_folder = setup

      client.create_disk(datacenter, datastore, disk_cid, disk_folder, 128)
      disk = client.find_disk(disk_cid, datastore, disk_folder)

      expect(disk.cid).to eq(disk_cid)
      expect(disk.size_in_mb).to eq(128)
    end

    it "returns nil when the disk can't be found" do
      disk_cid = "disk-#{SecureRandom.uuid}"

      client, datacenter, datastore, disk_folder = setup

      client.create_disk(datacenter, datastore, disk_cid, disk_folder, 128)
      disk = client.find_disk("not-the-#{disk_cid}", datastore, disk_folder)

      expect(disk).to be_nil
    end
  end

  def setup
    host = ENV.fetch('BOSH_VSPHERE_CPI_HOST')
    user = ENV.fetch('BOSH_VSPHERE_CPI_USER')
    password = ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD')
    disk_folder = ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH', 'ACCEPTANCE_BOSH_Disks')
    datacenter_name = ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC')
    vm_folder = ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER', 'ACCEPTANCE_BOSH_VMs')
    template_folder = ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER', 'ACCEPTANCE_BOSH_Templates')
    datastore_pattern = Regexp.new(ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN', 'jalapeno'))
    persistent_datastore_pattern = Regexp.new(ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN', 'jalapeno'))
    cluster_name = ENV.fetch('BOSH_VSPHERE_CPI_CLUSTER', 'BOSH_CL')
    resource_pool_name = ENV.fetch('BOSH_VSPHERE_CPI_RESOURCE_POOL', 'ACCEPTANCE_RP')

    cluster_configs = {cluster_name => VSphereCloud::ClusterConfig.new(cluster_name, {'resource_pool' => resource_pool_name})}
    logger = Logger.new(StringIO.new(""))

    client = VSphereCloud::Client.new("https://#{host}/sdk/vimService", logger: logger)
    client.login(user, password, 'en')

    datacenter = VSphereCloud::Resources::Datacenter.new({
      client: client,
      use_sub_folder: false,
      vm_folder: vm_folder,
      template_folder: template_folder,
      name: datacenter_name,
      disk_path: disk_folder,
      ephemeral_pattern: datastore_pattern,
      persistent_pattern: persistent_datastore_pattern,
      clusters: cluster_configs,
      logger: logger,
      mem_overcommit: 1.0
    })
    _, datastore = datacenter.persistent_datastores.first
    return client, datacenter, datastore, disk_folder
  end
end
