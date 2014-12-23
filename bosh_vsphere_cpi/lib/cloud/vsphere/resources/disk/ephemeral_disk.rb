require 'cloud/vsphere/resources/disk/disk_config'

module VSphereCloud
  class EphemeralDisk
    def initialize(size, folder_name, datastore)
      @folder_name = folder_name
      @datastore = datastore
      @size = size
    end

    def create_spec(controller_key)
      DiskConfig.new(@datastore.mob, filename, controller_key, @size).spec(create: true)
    end

    private

    def filename
      "[#{@datastore.name}] #{@folder_name}/ephemeral_disk.vmdk"
    end
  end
end
