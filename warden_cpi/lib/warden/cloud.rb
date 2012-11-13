require 'sys/filesystem'
require 'uuidtools'

module Bosh

  module WardenCloud

    class Cloud < Bosh::Cloud

      def initialize(options)
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
      # @param [String] disk_id
      # @return nil
      def attach_disk(vm_id, disk_id)
      end

      def detach_disk(vm_id, disk_id)
      end

      def validate_deployment(old_manifest, new_manifest)
      end

      private

      def disk_dir
        "/var/bosh/disk_images"
      end

      def have_enough_free_space?(size)
        stat = Sys::Filesystem.stat(disk_dir)
        size < stat.block_size * stat.blocks_available / 1024 / 1024
      end

      def create_disk_dir
        `mkdir -p #{disk_dir}`
      end

      def generate_disk_uuid
        UUIDTools::UUID.random_create.to_s
      end

      def create_disk_image(size)

        uuid = generate_disk_uuid
        file = File.join(dir, uuid)
        `dd if=/dev/null of=#{file} bs=1M seek=#{size} > /dev/null`
        return nil unless $?.to_i == 0

        `mkfs.ext4 -F #{file} > /dev/null`
        unless $?.to_i == 0
          `rm -f #{file}`
          return nil
        end

        uuid
      end
    end
  end
end
