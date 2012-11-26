module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"
    DEFAULT_STEMCELL_ROOT = "/var/vcap/stemcell"
    DEFAULT_DISK_ROOT = "/var/vcap/disk"
    DEFAULT_FS_TYPE = "ext4"

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
      @disk_properties = options["disk"] || {}

      setup_warden
      setup_stemcell
      setup_disk
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

      stemcell_id = stemcell_uuid
      stemcell_dir = stemcell_path(stemcell_id)

      with_thread_name("create_stemcell(#{image_path}, _)") do

        # Extract to tarball
        @logger.info("Extracting stemcell from #{image_path} to #{stemcell_dir}")
        FileUtils.mkdir_p(stemcell_dir)

        # This command needs priviledge because the stemcell contains device files,
        # which cannot be untared without priviledge
        sudo "tar -C #{stemcell_dir} -xzf #{image_path} 2>&1"

        # TODO Verify if it is a valid stemcell

        stemcell_id
      end
    rescue => e
      sudo "rm -rf #{stemcell_dir}" rescue nil
      cloud_error(e)
    end

    ##
    # Delete the stemcell
    # @param [String] id of the stemcell to be deleted
    # return nil
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id}, _)") do
        stemcell_dir = stemcell_path(stemcell_id)
        sudo "rm -rf #{stemcell_dir}"

        nil
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
    # Create a disk
    #
    # @param [Integer] size disk size in MB
    # @param [String] vm_locality vm id if known of the VM that this disk will
    #                 be attached to
    # return [String] disk id
    def create_disk(size, vm_locality = nil)
      not_used(vm_locality)

      disk = nil
      image_file = nil

      raise ArgumentError, "disk size <= 0" unless size > 0

      with_thread_name("create_disk(#{size}, _)") do
        disk = Models::Disk.new
        disk.image_path = image_file
        disk.attached = false

        disk.save

        image_file = image_path(disk.id)

        FileUtils.touch(image_file)
        File.truncate(image_file, size << 20) # 1 MB == 1<<20 Byte

        sh "mkfs -t #{@fs_type} -F #{image_file}"

        disk.id.to_s
      end
    rescue => e
      FileUtils.rm image_file if image_file
      disk.destroy if disk

      cloud_error(e)
    end

    ##
    # Delete a disk
    #
    # @param [String] disk id
    # return nil
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        disk = Models::Disk[disk_id.to_i]

        raise "Cannot find disk #{disk_id}" unless disk
        raise "Cannot delete attached disk" if disk.attached

        image_file = image_path(disk_id)
        FileUtils.rm image_file

        disk.destroy

        nil
      end
    rescue => e
      cloud_error(e)
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

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

    def image_path(disk_id)
      File.join(@disk_root, "#{disk_id}.img")
    end

    def setup_warden
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK

      @client = Warden::Client.new(@warden_unix_path)
    end

    def setup_stemcell
      @stemcell_root = @stemcell_properties["root"] || DEFAULT_STEMCELL_ROOT

      FileUtils.mkdir_p(@stemcell_root)
    end

    def setup_disk
      @disk_root = @disk_properties["root"] || DEFAULT_DISK_ROOT
      @fs_type = @disk_properties["fs"] || DEFAULT_FS_TYPE
    end

  end
end
