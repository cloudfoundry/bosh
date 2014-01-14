require 'digest/sha1'
require 'fileutils'
require 'securerandom'

module Bosh
  module Clouds
    class Dummy
      class NotImplemented < StandardError; end

      def initialize(options)
        if options['dir'].nil?
          raise ArgumentError, 'please provide base directory for dummy cloud'
        end

        @options = options
        @base_dir = options['dir']

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

      # rubocop:disable ParameterLists
      def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil, env = nil)
      # rubocop:enable ParameterLists
        root_dir = File.join(agent_base_dir(agent_id), 'root_dir')
        FileUtils.mkdir_p(File.join(root_dir, 'etc', 'logrotate.d'))

        write_agent_settings(agent_id, {
          agent_id: agent_id,
          blobstore: @options['agent']['blobstore'],
          ntp: [],
          disks: { persistent: {} },
          vm: { name: "vm-#{agent_id}" },
          mbus: @options['nats'],
        })

        agent_cmd = agent_cmd(agent_id, root_dir, :ruby)
        agent_log = "#{@options['dir']}/agent.#{agent_id}.log"
        agent_pid = Process.spawn(*agent_cmd, chdir: agent_base_dir(agent_id), out: agent_log, err: agent_log)
        Process.detach(agent_pid)

        FileUtils.mkdir_p(File.join(@base_dir, 'running_vms'))
        File.write(vm_file(agent_pid), agent_id)

        agent_pid.to_s
      end

      def delete_vm(vm_name)
        agent_pid = vm_name.to_i
        Process.kill('INT', agent_pid)
      # rubocop:disable HandleExceptions
      rescue Errno::ESRCH
      # rubocop:enable HandleExceptions
      ensure
        FileUtils.rm_rf(File.join(@base_dir, 'running_vms', vm_name))
      end

      def reboot_vm(vm)
        raise NotImplemented, 'Dummy CPI does not implement reboot_vm'
      end

      def has_vm?(vm_id)
        File.exists?(vm_file(vm_id))
      end

      def configure_networks(vm, networks)
        raise NotImplemented, 'Dummy CPI does not implement configure_networks'
      end

      def attach_disk(vm_id, disk_id)
        file = attachment_file(vm_id, disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)

        agent_id = agent_id_for_vm_id(vm_id)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'][disk_id] = 'attached'
        write_agent_settings(agent_id, settings)
      end

      def detach_disk(vm_id, disk_id)
        FileUtils.rm(attachment_file(vm_id, disk_id))

        agent_id = agent_id_for_vm_id(vm_id)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'].delete(disk_id)
        write_agent_settings(agent_id, settings)
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

      def snapshot_disk(_, metadata)
        snapshot_id = SecureRandom.hex
        file = snapshot_file(snapshot_id)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, metadata.to_json)
        snapshot_id
      end

      def delete_snapshot(snapshot_id)
        FileUtils.rm(snapshot_file(snapshot_id))
      end

      def validate_deployment(old_manifest, new_manifest)
        raise NotImplemented, 'Dummy CPI does not implement validate_deployment'
      end

      private

      def agent_id_for_vm_id(vm_id)
        File.read(vm_file(vm_id))
      end

      def agent_settings_file(agent_id)
        File.join(agent_base_dir(agent_id), 'bosh', 'settings.json')
      end

      def agent_base_dir(agent_id)
        "#{@options['dir']}/agent-base-dir-#{agent_id}"
      end

      def write_agent_settings(agent_id, settings)
        FileUtils.mkdir_p(File.dirname(agent_settings_file(agent_id)))
        File.write(agent_settings_file(agent_id), JSON.generate(settings))
      end

      def agent_cmd(agent_id, root_dir, agent_type)
        go_agent_exe = File.absolute_path('bosh/go_agent/out/bosh-agent')
        {
          ruby: %W[bosh_agent      -b #{agent_base_dir(agent_id)} -I dummy -r #{root_dir} --no-alerts],
          go:   %W[#{go_agent_exe} -b #{agent_base_dir(agent_id)} -I dummy -P dummy -M dummy],
        }[agent_type]
      end

      def read_agent_settings(agent_id)
        JSON.parse(File.read(agent_settings_file(agent_id)))
      end

      def stemcell_file(stemcell_id)
        File.join(@base_dir, "stemcell_#{stemcell_id}")
      end

      def vm_file(vm_id)
        File.join(@base_dir, 'running_vms', vm_id.to_s)
      end

      def disk_file(disk_id)
        File.join(@base_dir, 'disks', disk_id)
      end

      def attachment_file(vm_id, disk_id)
        File.join(@base_dir, 'attachments', vm_id, disk_id)
      end

      def snapshot_file(snapshot_id)
        File.join(@base_dir, 'snapshots', snapshot_id)
      end
    end
  end
end
