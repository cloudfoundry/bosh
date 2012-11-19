
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"
    DEFAULT_STEMCELL_ROOT = "/var/vcap/stemcell"
    DEFAULT_DISK_DIR = "/var/vcap/disk_images"
    DEFAULT_DB_TYPE = "sqlite"
    DEFAULT_DB_PATH = "/tmp/test.db"
    DEFAULT_POOL_START = 256
    DEFAULT_POOL_SIZE = 256

    attr_accessor :logger

    ##
    # Initialize BOSH Warden CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"] || {}
      @stemcell_properties = options["stemcell"] || {}
      @db_properties = options["db"] || {}
      @device_pool_properties = options["device_pool"] || {}
      @disk_dir = options["disk_dir"] || DEFAULT_DISK_DIR

      setup_warden
      setup_stemcell
      setup_db
      setup_disk_manager
    end

    ##
    # Create a stemcell using stemcell image
    # This method simply untar the stemcell image to a local directory. Warden
    # can use the rootfs within the image as a base fs.
    # @param [String] image_path local path to a stemcell image
    # @param [Hash] cloud_properties not used
    # return [String] stemcell id
    def create_stemcell(image_path, cloud_properties)
      not_used(cloud_properties)

      with_thread_name("create_stemcell(#{image_path}, _)") do
        stemcell_id = SecureRandom.uuid
        stemcell_path = stemcell_path(stemcell_id)

        # Extract to tarball
        @logger.info("Extracting stemcell from #{image_path} to #{stemcell_path}")
        FileUtils.mkdir_p(stemcell_path)
        Bosh::Exec.sh "tar -C #{stemcell_path} -xzf #{image_path} 2>&1"

        # TODO Verify if it is a valid stemcell

        stemcell_id
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Delete the stemcell
    # @param [String] id of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id}, _)") do
        stemcell_path = stemcell_path(stemcell_id)
        FileUtils.rm_rf(stemcell_path)
      end
    end

    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      # TODO to be implemented

      vm_uuid
    end

    def delete_vm(vm_id)
      # TODO to be implemented
    end

    def reboot_vm(vm_id)
      # no-op
    end

    def configure_networks(vm_id, networks)
      # no-op
    end

    ##
    # Creates a new disk image
    # @param [Integer] size disk size in MiB
    # @param [String] vm_locality not be used in warden cpi
    # @raise [Bosh::Clouds::NoDiskSpace] if system has not enough free space
    # @raise [Bosh::Clouds::CloudError] when meeting internal error
    # @return [String] disk id
    def create_disk(size, vm_locality = nil)
      not_used(vm_locality)

      with_thread_name("create_disk(#{size}, _)") do
        disk = @disk_manager.create_disk(size)
        begin
          @db.save_disk(disk)
        rescue
          @disk_manager.delete_disk(disk)
          raise
        end
        disk.uuid
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Delete a disk image
    # @param [String] disk_id
    # @raise [Bosh::Clouds::DiskNotFound] if disk not exist
    # @return nil
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        disk = @db.find_disk(disk_id)
        @db.delete_disk(disk)
        @disk_manager.delete_disk(disk)
      end
    rescue => e
      cloud_error(e)
    end

    ##
    # Attach a disk image to a vm
    # @param [String] vm_id warden container handle
    # @param [String] disk_id disk id
    # @return nil
    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    ##
    # Detach a disk image from a vm
    # @param [String] vm_id warden container handle
    # @param [String] disk_id disk id
    # @return nil
    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def validate_deployment(old_manifest, new_manifest)
      # no-op
    end

    private

    def not_used(var)
      # no-op
    end

    def stemcell_path(stemcell_id)
      File.join(@stemcell_root, stemcell_id)
    end

    def setup_device_pool(option)
      pool = []
      start = option["start_num"] || DEFAULT_POOL_START
      acount = option["count"] || DEFAULT_POOL_SIZE
      acount.times do |i|
        device_num = start + i
        pool.push(device_num) unless @db.device_occupied?(device_num)
      end
      DevicePool.new(pool)
    end

    def setup_warden
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK

      @client = Warden::Client.new(@warden_unix_path)
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

    def setup_db
      type = @db_properties["type"] || DEFAULT_DB_TYPE
      path = @db_properties["path"] || DEFAULT_DB_PATH
      @db = DB.new(type, path)
    end

    def setup_disk_manager
      @disk_manager = DiskManager.new(
        @disk_dir,
        setup_device_pool(@device_pool_properties)
      )
    end
  end
end
