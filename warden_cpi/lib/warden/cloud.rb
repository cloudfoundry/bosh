require "cloud"
require "uuidtools"
require "sys/filesystem"

module Bosh

  module WardenCloud

    class Cloud < Bosh::Cloud

      attr_accessor :logger
      attr_accessor :disk_dir

      def initialize(options)
        @logger = Bosh::Clouds::Config.logger
        @disk_dir = options[:disk_dir] || "/var/bosh/disk_images"
      end

      def create_stemcell(image_path, cloud_properties)
      end

      def delete_stemcell(stemcell_id)
      end

      def create_vm(agent_id, stemcell_id, resource_pool,
                    networks, disk_locality = nil, environment = nil)
      end

      def delete_vm(vm_id)
      end

      def reboot_vm(vm_id)
      end

      def configure_networks(vm_id, networks)
      end

      ##
      # Creates a new disk image
      # @param [Integer] size disk size in MiB
      # @return [String] disk id
      def create_disk(size)
        @logger.debug("Entering create_disk, size == #{size}")
        return nil unless size > 0
        raise Bosh::Clouds::NoDiskSpace.new(false) unless have_enough_free_space?(size)
        create_disk_dir unless File.exist?(disk_dir)
        create_disk_image(size)
      end

      ##
      # Delete a disk image
      # @param [String] disk_id
      # @return nil
      def delete_disk(disk_id)
      end

      ##
      # Attach a disk image to a vm
      # @param [String] vm_id warden container handle
      # @param [String] disk_id disk id
      # @return nil
      def attach_disk(vm_id, disk_id)
      end

      ##
      # Detach a disk image from a vm
      # @param [String] vm_id warden container handle
      # @param [String] disk_id disk id
      # @return nil
      def detach_disk(vm_id, disk_id)
      end

      def validate_deployment(old_manifest, new_manifest)
      end

      private

      def have_enough_free_space?(size)
        stat = Sys::Filesystem.stat(disk_dir)
        size < stat.block_size * stat.blocks_available / 1024 / 1024
      end

      def create_disk_dir
        @logger.info("Disk dir not exists, creating it ...")
        `mkdir -p #{disk_dir}`
      end

      def generate_disk_uuid
        UUIDTools::UUID.random_create.to_s
      end

      def create_disk_image(size)

        uuid = generate_disk_uuid
        file = File.join(disk_dir, uuid)

        @logger.info("Ready to crate disk image #{uuid} in #{disk_dir}")

        `dd if=/dev/null of=#{file} bs=1M seek=#{size} > /dev/null 2>&1`
        return nil unless $?.to_i == 0

        `mkfs.ext4 -F #{file} > /dev/null 2>&1`
        unless $?.to_i == 0
          `rm -f #{file}`
          return nil
        end

        @logger.info("Sucessfully creating disk image #{uuid}")

        uuid
      end
    end
  end
end
