require 'digest/sha1'
require 'fileutils'
require 'securerandom'

module Bosh

  module Clouds
    class Dummy

      class NotImplemented < StandardError; end

      def initialize(options)
        if options["dir"].nil?
          raise ArgumentError, "please provide base directory for dummy cloud"
        end

        @options = options
        @base_dir = options["dir"]
        FileUtils.mkdir_p(@base_dir)
      rescue Errno::EACCES
        raise ArgumentError, "cannot create dummy cloud base directory #{@base_dir}"
      end

      def create_stemcell(image, _)
        stemcell_id = Digest::SHA1.hexdigest(File.read(image))
        File.write(stemcell_file(stemcell_id), image)
        stemcell_id
      end

      def delete_stemcell(stemcell_cid)
        FileUtils.rm(stemcell_file(stemcell_cid))
      end

      def blobstore_uri
        properties = @options['agent']['blobstore']['options']
        uri = URI(properties['endpoint'])
        uri.user = properties['user']
        uri.password = properties['password']
        uri.to_s
      end

      def nats_uri
        @options['nats']
      end

      def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil, env = nil)
        agent_base_dir = "#{@options['dir']}/agent-base-dir-#{agent_id}"

        root_dir = File.join(agent_base_dir, 'root_dir')
        FileUtils.mkdir_p(File.join(root_dir, 'etc', 'logrotate.d'))

        # FIXME: if there is a need to start this dummy cloud agent with alerts turned on
        # then port should be overriden for each agent, otherwise all but first won't start
        # (won't be able to bind to port)
        agent_cmd = %W[bosh_agent -a #{agent_id} -s #{blobstore_uri} -p simple -b #{agent_base_dir} -n #{nats_uri} -r #{root_dir} --no-alerts]
        agent_log = "#{@options['dir']}/agent.#{agent_id}.log"
        agent_pid = Process.spawn(*agent_cmd, out: agent_log, err: agent_log)

        Process.detach(agent_pid)

        FileUtils.mkdir_p(File.join(@base_dir, "running_vms"))
        FileUtils.touch(vm_file(agent_pid))

        agent_pid.to_s
      end

      def delete_vm(vm_name)
        agent_pid = vm_name.to_i
        Process.kill("INT", agent_pid)
      rescue Errno::ESRCH
        # don't care :)
      ensure
        FileUtils.rm_rf(File.join(@base_dir, "running_vms", vm_name))
      end

      def reboot_vm(vm)
        raise NotImplemented, "reboot_vm"
      end

      def has_vm?(vm_id)
        File.exists?(vm_file(vm_id))
      end

      def configure_networks(vm, networks)
        raise NotImplemented, "configure_networks"
      end

      def attach_disk(vm_id, disk_id)
        file = attachment_file(vm_id, disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)
      end

      def detach_disk(vm_id, disk_id)
        FileUtils.rm(attachment_file(vm_id, disk_id))
      end

      def create_disk(size, vm_locality = nil)
        disk_id = SecureRandom.hex
        file = disk_file(disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, size.to_s)
        disk_id
      end

      def delete_disk(disk_id)
        FileUtils.rm(disk_file(disk_id))
      end

      def snapshot_disk(disk_id)
        snapshot_id = SecureRandom.hex
        file = snapshot_file(snapshot_id)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, disk_id)
        snapshot_id
      end

      def delete_snapshot(snapshot_id)
        FileUtils.rm(snapshot_file(snapshot_id))
      end

      def validate_deployment(old_manifest, new_manifest)
        # There is TODO in vSphere CPI that questions the necessity of this method
        raise NotImplemented, "validate_deployment"
      end

      private

      def stemcell_file(stemcell_id)
        File.join(@base_dir, "stemcell_#{stemcell_id}")
      end

      def vm_file(vm_id)
        File.join(@base_dir, "running_vms", vm_id.to_s)
      end

      def disk_file(disk_id)
        File.join(@base_dir, "disks", disk_id)
      end

      def attachment_file(vm_id, disk_id)
        File.join(@base_dir, "attachments", vm_id, disk_id)
      end

      def snapshot_file(snapshot_id)
        File.join(@base_dir, "snapshots", snapshot_id)
      end
    end
  end
end
