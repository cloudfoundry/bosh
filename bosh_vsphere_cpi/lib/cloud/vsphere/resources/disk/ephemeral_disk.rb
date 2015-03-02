require 'cloud/vsphere/resources/disk/disk_config'

module VSphereCloud
  class EphemeralDisk
    def initialize(size_in_mb, folder_name, datastore)
      @folder_name = folder_name
      @datastore = datastore
      @size_in_mb = size_in_mb
    end

    def create_spec(controller_key)
      DiskConfig.new(@datastore.mob, filename, controller_key, @size_in_mb).spec(create: true)
    end

    private

    def filename
      "[#{@datastore.name}] #{@folder_name}/ephemeral_disk.vmdk"
    end
  end
end
