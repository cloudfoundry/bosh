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
        vm_name   = "vm-%d-%d" % [ rand(30000), rand(30000) ]
        agent_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "..", "agent"))
        
        agent_cmd = File.join(agent_dir, "bin", "agent -a #{agent_id} -r localhost:63795 -s bs_admin:bs_pass@http://127.0.0.1:9590")

        @agent_pid = fork do
          exec "ruby #{agent_cmd}"
        end

        Process.detach(@agent_pid)

        FileUtils.mkdir_p(File.join(@base_dir, "running_vms"))
        FileUtils.touch(File.join(@base_dir, "running_vms", vm_name))
        vm_name
      end

      def delete_vm(vm_cid)
        if @agent_pid
          Process.kill("INT", @agent_pid)
        end
        FileUtils.rm_rf(File.join(@base_dir, "running_vms", vm_cid))
      end

      def configure_networks(vm, networks)
        raise NotImplemented, "configure_networks"
      end

      def attach_disk(vm, disk)
        raise NotImplemented, "attach_disk"
      end

      def detach_disk(vm, disk)
        raise NotImplemented, "detach_disk"
      end

      def create_disk(size, vm_locality = nil)
        raise NotImplemented, "create_disk"
      end

      def delete_disk(disk)
        raise NotImplemented, "delete_disk"
      end

      def validate_deployment(old_manifest, new_manifest)
        # There is TODO in vSphere CPI that questions the necessity of this method
        raise NotImplemented, "validate_deployment"
      end

    end
  end
end
