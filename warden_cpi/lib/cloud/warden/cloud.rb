
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    attr_accessor :logger

    def initialize(options)
      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"]
      @disk_dir = options["disk_dir"] || "/var/vcap/disk_images"

      @logger = Bosh::Clouds::Config.logger
      @client = Warden::Client.new(@warden_properties["unix_domain_path"])
    end

    def create_stemcell(image_path, cloud_properties)
      # TODO to be implemented

      SecureRandom.uuid
    end

    def delete_stemcell(stemcell_id)
      # TODO to be implemented
    end

    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      # TODO to be implemented

      SecureRandom.uuid
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
      @logger.debug("Entering create_disk, size == #{size}")
      return nil unless size > 0
      raise Bosh::Clouds::NoDiskSpace.new(false) unless have_enough_free_space?(size)
      create_disk_dir unless File.exist?(@disk_dir)
      create_disk_image(size)
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

    def exec_sh(cmd)
      Bosh::Exec.sh(cmd, :on_error => :return)
    end

    def have_enough_free_space?(size)
      stat = Sys::Filesystem.stat(@disk_dir)
      size < stat.block_size * stat.blocks_available / 1024 / 1024
    end

    def create_disk_dir
      @logger.info("Disk dir not exists, creating it ...")
      cmd = "mkdir -p #{@disk_dir} > /dev/null 2>&1"
      raise Bosh::Clouds::CloudError.new, "Creating disk dir failed" if exec_sh(cmd).failed?
    end

    def generate_disk_uuid
      SecureRandom.uuid
    end

    def create_disk_image(size)

      uuid = generate_disk_uuid
      file = File.join(@disk_dir, uuid)

      @logger.info("Ready to crate disk image #{uuid} in #{@disk_dir}")

      cmd = "dd if=/dev/null of=#{file} bs=1M seek=#{size} > /dev/null 2>&1"
      raise Bosh::Clouds::CloudError.new, "Creating disk image failed" if exec_sh(cmd).failed?

      cmd = "mkfs.ext4 -F #{file} > /dev/null 2>&1"
      if exec_sh(cmd).failed?
        exec_sh("rm -f #{file} > /dev/null 2>&1")
        raise Bosh::Clouds::CloudError.new, "Making file system for disk failed"
      end

      @logger.info("Sucessfully creating disk image #{uuid}")

      uuid
    end

    def not_used(var)
      # no-op
    end

  end
end
