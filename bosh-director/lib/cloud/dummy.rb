require 'digest/sha1'
require 'fileutils'
require 'securerandom'

module Bosh
  module Clouds
    class Dummy
      class NotImplemented < StandardError; end

      attr_reader :commands

      def initialize(options)
        @options = options

        @base_dir = options['dir']
        if @base_dir.nil?
          raise ArgumentError, 'Must specify dir'
        end

        @running_vms_dir = File.join(@base_dir, 'running_vms')
        @tmp_dir = File.join(@base_dir, 'tmp')
        FileUtils.mkdir_p(@tmp_dir)

        @logger = Logging::Logger.new('DummyCPI')
        @logger.add_appenders(Logging.appenders.io(
          'DummyCPIIO',
          options['log_buffer'] || STDOUT
        ))

        @commands = CommandTransport.new(@base_dir, @logger)

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
        @logger.info('Dummy: create_vm')

        ips = []
        cmd = commands.next_create_vm_cmd

        if cmd.ip_address
          # special case used by dynamic IP assignment tests: CPI always chooses its own IP
          write_agent_default_network(agent_id, cmd.ip_address)
          ips << { 'network' => 'cloud', 'ip' => cmd.ip_address }
        else
          networks.each do |network_name, network|
            ips << { 'network' => network_name, 'ip' => network['ip'] }
          end
        end

        allocate_ips(ips)

        write_agent_settings(agent_id, {
          agent_id: agent_id,
          blobstore: @options['agent']['blobstore'],
          ntp: [],
          disks: { persistent: {} },
          networks: networks,
          vm: { name: "vm-#{agent_id}" },
          cert: '',
          mbus: @options['nats'],
        })

        agent_pid = spawn_agent_process(agent_id)

        FileUtils.mkdir_p(@running_vms_dir)
        File.write(vm_file(agent_pid), JSON.dump("agent_id" => agent_id, "ips" => ips))

        agent_pid.to_s
      end

      def delete_vm(vm_name)
        agent_pid = vm_name.to_i
        Process.kill('KILL', agent_pid)
      # rubocop:disable HandleExceptions
      rescue Errno::ESRCH
      # rubocop:enable HandleExceptions
      ensure
        free_ips(ips_for_vm_id(vm_name)) if has_vm?(vm_name)
        FileUtils.rm_rf(File.join(@base_dir, 'running_vms', vm_name))
      end

      def reboot_vm(vm_id)
        raise NotImplemented, 'Dummy CPI does not implement reboot_vm'
      end

      def has_vm?(vm_id)
        File.exists?(vm_file(vm_id))
      end

      def has_disk?(disk_id)
        File.exists?(disk_file(disk_id))
      end

      def configure_networks(vm_id, networks)
        cmd = commands.next_configure_networks_cmd(vm_id)

        # The only configure_networks test so far only tests the negative case.
        # If a positive case is added, the agent will need to be re-started.
        # Normally runit would handle that.
        if cmd.not_supported || true
          raise NotSupported, 'Dummy CPI was configured to return NotSupported'
        end
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

      def create_disk(size, cloud_properties, vm_locality = nil)
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

      # Additional Dummy test helpers

      def vm_cids
        # Shuffle so that no one relies on the order of VMs
        Dir.glob(File.join(@running_vms_dir, '*')).map { |vm| File.basename(vm) }.shuffle
      end

      def disk_cids
        # Shuffle so that no one relies on the order of disks
        Dir.glob(disk_file('*')).map { |disk| File.basename(disk) }.shuffle
      end

      def kill_agents
        vm_cids.each do |agent_pid|
          begin
            Process.kill('KILL', agent_pid.to_i)
          # rubocop:disable HandleExceptions
          rescue Errno::ESRCH
          # rubocop:enable HandleExceptions
          end
        end
      end

      def agent_log_path(agent_id)
        "#{@base_dir}/agent.#{agent_id}.log"
      end

      def set_vm_metadata(vm, metadata); end

      private

      def spawn_agent_process(agent_id)
        root_dir = File.join(agent_base_dir(agent_id), 'root_dir')
        FileUtils.mkdir_p(File.join(root_dir, 'etc', 'logrotate.d'))

        agent_cmd = agent_cmd(agent_id)
        agent_log = agent_log_path(agent_id)

        agent_pid = Process.spawn(
          { 'TMPDIR' => @tmp_dir },
          *agent_cmd,
          {
            chdir: agent_base_dir(agent_id),
            out: agent_log,
            err: agent_log,
          }
        )

        Process.detach(agent_pid)

        agent_pid
      end

      def allocate_ips(ips)
        ips.each do |ip|
          begin
            network_dir = File.join(@base_dir, 'dummy_cpi_networks', ip['network'])
            FileUtils.makedirs(network_dir)
            open(File.join(network_dir, ip['ip']), File::WRONLY|File::CREAT|File::EXCL).close
          rescue Errno::EEXIST
            # at this point we should actually free all the IPs we successfully allocated before the collision,
            # but in practice the tests only feed in one IP per VM so that cleanup code would never be exercised
            raise "IP Address #{ip['ip']} in network '#{ip['network']}' is already in use"
          end
        end
      end

      def free_ips(ips)
        ips.each do |ip|
          FileUtils.rm_rf(File.join(@base_dir, 'dummy_cpi_networks', ip['network'], ip['ip']))
        end
      end

      def ips_for_vm_id(vm_id)
        JSON.parse(File.read(vm_file(vm_id)))['ips']
      end

      def agent_id_for_vm_id(vm_id)
        JSON.parse(File.read(vm_file(vm_id)))['agent_id']
      end

      def agent_settings_file(agent_id)
        # Even though dummy CPI has complete access to agent execution file system
        # it should never write directly to settings.json because
        # the agent is responsible for retrieving the settings from the CPI.
        File.join(agent_base_dir(agent_id), 'bosh', 'dummy-cpi-agent-env.json')
      end

      def agent_base_dir(agent_id)
        "#{@base_dir}/agent-base-dir-#{agent_id}"
      end

      def write_agent_settings(agent_id, settings)
        FileUtils.mkdir_p(File.dirname(agent_settings_file(agent_id)))
        File.write(agent_settings_file(agent_id), JSON.generate(settings))
      end

      def write_agent_default_network(agent_id, ip_address)
        # Agent looks for following file to resolve default network on dummy infrastructure
        path = File.join(agent_base_dir(agent_id), 'bosh', 'dummy-default-network-settings.json')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate('ip' => ip_address))
      end

      def agent_cmd(agent_id)
        agent_config_file = File.join(agent_base_dir(agent_id), 'agent.json')

        agent_config = {
          'Infrastructure' => {
            'Settings' => {
              'Sources' => [{
                'Type' => 'File',
                'SettingsPath' => agent_settings_file(agent_id)
              }],
              'UseRegistry' => true
            }
          }
        }

        File.write(agent_config_file, JSON.generate(agent_config))

        go_agent_exe = File.expand_path('../../../../go/src/github.com/cloudfoundry/bosh-agent/out/bosh-agent', __FILE__)

        %W[#{go_agent_exe} -b #{agent_base_dir(agent_id)} -P dummy -M dummy-nats -C #{agent_config_file}]
      end

      def read_agent_settings(agent_id)
        JSON.parse(File.read(agent_settings_file(agent_id)))
      end

      def stemcell_file(stemcell_id)
        File.join(@base_dir, "stemcell_#{stemcell_id}")
      end

      def vm_file(vm_id)
        File.join(@running_vms_dir, vm_id.to_s)
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

      # Example file system layout for arranging commands information.
      # Currently uses file system as transport but could be switch to use NATS.
      #   base_dir/cpi/create_vm/next -> {"something": true}
      #   base_dir/cpi/configure_networks/<vm_id> -> (presence)
      class CommandTransport
        def initialize(base_dir, logger)
          @cpi_commands = File.join(base_dir, 'cpi_commands')
          @logger = logger
        end

        def make_configure_networks_not_supported(vm_id)
          @logger.info("Making configure_networks for #{vm_id} raise NotSupported")
          path = File.join(@cpi_commands, 'configure_networks', vm_id)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')
        end

        def next_configure_networks_cmd(vm_id)
          @logger.info("Reading configure_networks configuration for #{vm_id}")
          vm_path = File.join(@cpi_commands, 'configure_networks', vm_id)
          vm_supported = File.exists?(vm_path)
          FileUtils.rm_rf(vm_path)
          ConfigureNetworksCommand.new(vm_supported)
        end

        def make_create_vm_always_use_dynamic_ip(ip_address)
          @logger.info("Making create_vm method to set ip address #{ip_address}")
          always_path = File.join(@cpi_commands, 'create_vm', 'always')
          FileUtils.mkdir_p(File.dirname(always_path))
          File.write(always_path, ip_address)
        end

        def next_create_vm_cmd
          @logger.info('Reading create_vm configuration')
          always_path = File.join(@cpi_commands, 'create_vm', 'always')
          ip_address = File.read(always_path) if File.exists?(always_path)
          CreateVmCommand.new(ip_address)
        end
      end

      class ConfigureNetworksCommand < Struct.new(:not_supported); end
      class CreateVmCommand < Struct.new(:ip_address); end
    end
  end
end
