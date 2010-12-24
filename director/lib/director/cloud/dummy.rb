require "digest/sha1"
require "fileutils"

module Bosh

  module Director
    class DummyCloud

      class NotImplemented < StandardError; end

      def initialize(options)
        if options["dir"].nil?
          raise ArgumentError, "please provide base directory for dummy cloud"
        end

        @base_dir = options["dir"]
        FileUtils.mkdir_p(@base_dir)
      rescue Errno::EACCES
        raise ArgumentError, "cannot create dummy cloud base directory #{@base_dir}"
      end

      def create_stemcell(image, _)
        stemcell_id = Digest::SHA1.hexdigest(File.read(image))
        File.open(File.join(@base_dir, "stemcell_#{stemcell_id}"), "w") do |f|
          f.write(image)
        end

        stemcell_id
      end

      def delete_stemcell(stemcell_cid)
        FileUtils.rm(File.join(@base_dir, "stemcell_#{stemcell_cid}"))
      end

      def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)
      end

      def delete_vm(vm)
      end

      def configure_networks(vm, networks)
      end

      def attach_disk(vm, disk)
      end

      def detach_disk(vm, disk)
      end

      def create_disk(size, vm_locality = nil)
      end

      def delete_disk(disk)
      end

      def validate_deployment(old_manifest, new_manifest)
      end

    end
  end
end
