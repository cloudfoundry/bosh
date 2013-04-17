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
        File.open(File.join(@base_dir, "stemcell_#{stemcell_id}"), "w") do |f|
          f.write(image)
        end

        stemcell_id
      end

      def delete_stemcell(stemcell_cid)
        FileUtils.rm(File.join(@base_dir, "stemcell_#{stemcell_cid}"))
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
        agent_cmd = "bosh_agent -a #{agent_id} -s #{blobstore_uri} -p simple -b #{agent_base_dir} -n #{nats_uri} -r #{root_dir} --no-alerts"

        agent_pid = fork do
          # exec will actually fork off another process (due to shell expansion),
          # so in order to kill all these new processes when cleaning up we need them
          # in a single process group.
          Process.setpgid(0, 0)
          exec "bundle exec #{agent_cmd} > #{@options['dir']}/agent.#{agent_id}.log 2>&1"
        end

        Process.detach(agent_pid)

        FileUtils.mkdir_p(File.join(@base_dir, "running_vms"))
        FileUtils.touch(File.join(@base_dir, "running_vms", agent_pid.to_s))

        agent_pid.to_s
      end

      def delete_vm(vm_name)
        agent_pid = vm_name.to_i
        Process.kill("INT", -1 * agent_pid) # Kill the whole process group
      rescue Errno::ESRCH
        # don't care :)
      ensure
        FileUtils.rm_rf(File.join(@base_dir, "running_vms", vm_name))
      end

      def reboot_vm(vm)
        raise NotImplemented, "reboot_vm"
      end

      def has_vm?(pid)
        begin
          Process.kill(0, pid.to_i)
          true
        rescue Errno::ESRCH
          false
        end
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

      def snapshot_disk(disk_id)
        snapshot_id = SecureRandom.hex
        File.open(File.join(@base_dir, "snapshot_#{snapshot_id}"), 'w') do |f|
          f.write(disk_id)
        end

        snapshot_id
      end

      def delete_snapshot(snapshot_id)
        FileUtils.rm(File.join(@base_dir, "snapshot_#{snapshot_id}"))
      end

      def validate_deployment(old_manifest, new_manifest)
        # There is TODO in vSphere CPI that questions the necessity of this method
        raise NotImplemented, "validate_deployment"
      end

    end
  end
end
