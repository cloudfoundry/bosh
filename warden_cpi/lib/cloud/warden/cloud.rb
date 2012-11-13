
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"
    DEFAULT_STEMCELL_ROOT = "/var/vcap/stemcell"

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
      @db_properties = options["db"]
      @device_pool_properties = options["device_pool"] || {}

      @disk_manager = DiskManager.new(options["disk"])

      setup_warden
      setup_stemcell
      setup_db
      setup_device_pool
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
        disk = Model::Disk.new(disk_uuid, @device_pool.acquire)

        begin
          @disk_manager.create_disk(disk, size)
          @db.save_disk(disk)
        rescue
          @device_pool.release(disk.device_num)
          if @disk_manager.disk_exist?(disk)
            @disk_manager.delete_disk(disk)
          end
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
    # @return nil
    def delete_disk(disk_id)
      # TODO to be implemented
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

    class DevicePool

      def initialize(pool)
        @pool = pool
      end

      def acquire
        device_num = @pool.delete_at(0)
        unless device_num
          raise Bosh::Clouds::CloudError.new
        end
        device_num
      end

      def release(device_num)
        @pool.push(device_num)
      end
    end

    class DBWrapper

      def initialize(db)
        @db = db
      end

      def device_exist?(device_num)
        items = @db[:disk]
        items.each do |item|
          return true if item[:device_num] == device_num
        end
        false
      end

      def save_disk(disk)
        items = @db[:disk]
        items.insert(:uuid => "#{disk.uuid}", :device_num => "#{device_num}")
      end
    end

    def not_used(var)
      # no-op
    end

    def stemcell_path(stemcell_id)
      File.join(@stemcell_root, stemcell_id)
    end

    def setup_db
      db_type = @db_properties["type"]
      db_file = @db_properties["path"]

      if db_type != "sqlite"
        raise Bosh::Clouds::NotSupported.new, "#{db_type} not supported"
      end

      FileUtils.mkdir_p(File.dirname(db_file))
      db = Sequel.connect("#{db_type}://#{db_file}")

      db.create_table? :disk do
        primary_key String :uuid
        Int :device_num
      end

      db.create_table? :disk_mapping do
        primary_key String :disk_id
        String :container_id
        String :device_path
      end

      @db = DBWrapper.new(db)
    end

    def setup_device_pool
      pool = []
      pool_start_num = @device_pool_properties["start_num"]
      pool_count = @device_pool_properties["count"]
      pool_count.times do |i|
        device_num = pool_start_num + i
        pool.push(device_num) unless @db.device_exist?(device_num)
      end
      @device_pool = DevicePool.new(pool)
    end

    def setup_warden
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK

      @client = Warden::Client.new(@warden_unix_path)
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

  end
end
