require 'digest/sha1'
require 'fileutils'
require 'securerandom'
require 'membrane'

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
        @vm_repo = VMRepo.new(@running_vms_dir)
        @tmp_dir = File.join(@base_dir, 'tmp')
        FileUtils.mkdir_p(@tmp_dir)

        @logger = Logging::Logger.new('DummyCPI')
        @logger.add_appenders(Logging.appenders.io(
          'DummyCPIIO',
          options['log_buffer'] || STDOUT
        ))

        @commands = CommandTransport.new(@base_dir, @logger)
        @inputs_recorder = InputsRecorder.new(@base_dir, @logger)

        FileUtils.mkdir_p(@base_dir)
      rescue Errno::EACCES
        raise ArgumentError, "cannot create dummy cloud base directory #{@base_dir}"
      end

      CREATE_STEMCELL_SCHEMA = Membrane::SchemaParser.parse { {image_path: String, cloud_properties: Hash} }
      def create_stemcell(image_path, cloud_properties)
        validate_and_record_inputs(CREATE_STEMCELL_SCHEMA, __method__, image_path, cloud_properties)

        stemcell_id = Digest::SHA1.hexdigest(File.read(image_path))
        File.write(stemcell_file(stemcell_id), image_path)
        stemcell_id
      end

      DELETE_STEMCELL_SCHEMA = Membrane::SchemaParser.parse { {stemcell_id: String} }
      def delete_stemcell(stemcell_id)
        validate_and_record_inputs(DELETE_STEMCELL_SCHEMA, __method__, stemcell_id)
        FileUtils.rm(stemcell_file(stemcell_id))
      end

      CREATE_VM_SCHEMA = Membrane::SchemaParser.parse do
        {
          agent_id: String,
          stemcell_id: String,
          cloud_properties: Hash,
          networks: Hash,
          disk_cids: [String],
          env: Hash,
        }
      end
      # rubocop:disable ParameterLists
      def create_vm(agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)
      # rubocop:enable ParameterLists
        @logger.info('Dummy: create_vm')
        validate_and_record_inputs(CREATE_VM_SCHEMA, __method__, agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)

        cmd = commands.next_create_vm_cmd

        if cmd.failed?
          raise Bosh::Clouds::CloudError.new("Creating vm failed")
        end

        write_agent_default_network(agent_id, cmd.ip_address) if cmd.ip_address

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
        vm = VM.new(agent_pid.to_s, agent_id, cloud_properties)

        @vm_repo.save(vm)

        vm.id
      end

      DELETE_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def delete_vm(vm_cid)
        validate_and_record_inputs(DELETE_VM_SCHEMA, __method__, vm_cid)
        commands.wait_for_unpause_delete_vms
        agent_pid = vm_cid.to_i
        Process.kill('KILL', agent_pid)
      # rubocop:disable HandleExceptions
      rescue Errno::ESRCH
      # rubocop:enable HandleExceptions
      ensure
        FileUtils.rm_rf(File.join(@base_dir, 'running_vms', vm_cid))
      end

      REBOOT_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def reboot_vm(vm_cid)
        validate_and_record_inputs(__method__, vm_cid)
        raise NotImplemented, 'Dummy CPI does not implement reboot_vm'
      end

      HAS_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def has_vm?(vm_cid)
        validate_and_record_inputs(HAS_VM_SCHEMA, __method__, vm_cid)
        @vm_repo.exists?(vm_cid)
      end

      HAS_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String} }
      def has_disk?(disk_id)
        validate_and_record_inputs(HAS_DISK_SCHEMA, __method__, disk_id)
        File.exists?(disk_file(disk_id))
      end

      CONFIGURE_NETWORKS_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, networks: Hash}}
      def configure_networks(vm_cid, networks)
        validate_and_record_inputs(CONFIGURE_NETWORKS_SCHEMA, __method__, vm_cid, networks)
        cmd = commands.next_configure_networks_cmd(vm_cid)

        # The only configure_networks test so far only tests the negative case.
        # If a positive case is added, the agent will need to be re-started.
        # Normally runit would handle that.
        if cmd.not_supported || true
          raise NotSupported, 'Dummy CPI was configured to return NotSupported'
        end
      end

      ATTACH_DISK_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, disk_id: String} }
      def attach_disk(vm_cid, disk_id)
        validate_and_record_inputs(ATTACH_DISK_SCHEMA, __method__, vm_cid, disk_id)
        file = attachment_file(vm_cid, disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)

        agent_id = agent_id_for_vm_id(vm_cid)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'][disk_id] = 'attached'
        write_agent_settings(agent_id, settings)
      end

      DETACH_DISK_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, disk_id: String} }
      def detach_disk(vm_cid, disk_id)
        validate_and_record_inputs(DETACH_DISK_SCHEMA, __method__, vm_cid, disk_id)
        FileUtils.rm(attachment_file(vm_cid, disk_id))

        agent_id = agent_id_for_vm_id(vm_cid)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'].delete(disk_id)
        write_agent_settings(agent_id, settings)
      end

      CREATE_DISK_SCHEMA = Membrane::SchemaParser.parse { {size: Integer, cloud_properties: Hash, vm_locality: String} }
      def create_disk(size, cloud_properties, vm_locality)
        validate_and_record_inputs(CREATE_DISK_SCHEMA, __method__, size, cloud_properties, vm_locality)
        disk_id = SecureRandom.hex
        file = disk_file(disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, size.to_s)
        disk_id
      end

      DELTE_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String} }
      def delete_disk(disk_id)
        validate_and_record_inputs(DELTE_DISK_SCHEMA, __method__, disk_id)
        FileUtils.rm(disk_file(disk_id))
      end

      SNAPSHOT_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String, metadata: Hash} }
      def snapshot_disk(disk_id, metadata)
        validate_and_record_inputs(SNAPSHOT_DISK_SCHEMA, __method__, disk_id, metadata)
        snapshot_id = SecureRandom.hex
        file = snapshot_file(snapshot_id)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, metadata.to_json)
        snapshot_id
      end

      DELETE_SNAPSHOT_SCHEMA = Membrane::SchemaParser.parse { {snapshot_id: String} }
      def delete_snapshot(snapshot_id)
        validate_and_record_inputs(DELETE_SNAPSHOT_SCHEMA, __method__, snapshot_id)
        FileUtils.rm(snapshot_file(snapshot_id))
      end

      SET_VM_METADATA_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, metadata: Hash} }
      def set_vm_metadata(vm_cid, metadata)
        validate_and_record_inputs(SET_VM_METADATA_SCHEMA, __method__, vm_cid, metadata)
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

      def read_cloud_properties(vm_cid)
        @vm_repo.load(vm_cid).cloud_properties
      end

      def invocations
        @inputs_recorder.read_all
      end

      def invocations_for_method(method)
        @inputs_recorder.read(method)
      end

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

      def agent_id_for_vm_id(vm_cid)
        @vm_repo.load(vm_cid).agent_id
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

      def disk_file(disk_id)
        File.join(@base_dir, 'disks', disk_id)
      end

      def attachment_file(vm_cid, disk_id)
        File.join(@base_dir, 'attachments', vm_cid, disk_id)
      end

      def snapshot_file(snapshot_id)
        File.join(@base_dir, 'snapshots', snapshot_id)
      end

      def validate_and_record_inputs(schema, the_method, *args)
        parameter_names_to_values = parameter_names_to_values(the_method, *args)
        begin
          schema.validate(parameter_names_to_values)
        rescue Membrane::SchemaValidationError => err
          raise ArgumentError, "Invalid arguments sent to #{the_method}: #{err.message}"
        end
        record_inputs(the_method, parameter_names_to_values)
      end

      def record_inputs(method, args)
        @inputs_recorder.record(method, args)
      end

      def parameter_names_to_values(the_method, *the_method_args)
        hash = {}
        method(the_method).parameters.each_with_index do |param, index|
          hash[param[1]] = the_method_args[index]
        end
        hash
      end

      # Example file system layout for arranging commands information.
      # Currently uses file system as transport but could be switch to use NATS.
      #   base_dir/cpi/create_vm/next -> {"something": true}
      #   base_dir/cpi/configure_networks/<vm_cid> -> (presence)
      class CommandTransport
        def initialize(base_dir, logger)
          @cpi_commands = File.join(base_dir, 'cpi_commands')
          @logger = logger
        end

        def pause_delete_vms
          @logger.info("Pausing delete_vms")
          path = File.join(@cpi_commands, 'pause_delete_vms')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')
        end

        def unpause_delete_vms
          @logger.info("Unpausing delete_vms")
          FileUtils.rm_rf File.join(@cpi_commands, 'pause_delete_vms')
          FileUtils.rm_rf File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
        end

        def wait_for_delete_vms
          @logger.info("Wait for delete_vms")
          path = File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
          sleep(0.1) until File.exists?(path)
        end

        def wait_for_unpause_delete_vms
          @logger.info("Wait for unpausing delete_vms")
          path = File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')

          path = File.join(@cpi_commands, 'pause_delete_vms')
          sleep(0.1) while File.exists?(path)
        end

        def make_configure_networks_not_supported(vm_cid)
          @logger.info("Making configure_networks for #{vm_cid} raise NotSupported")
          path = File.join(@cpi_commands, 'configure_networks', vm_cid)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')
        end

        def next_configure_networks_cmd(vm_cid)
          @logger.info("Reading configure_networks configuration for #{vm_cid}")
          vm_path = File.join(@cpi_commands, 'configure_networks', vm_cid)
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

        def make_create_vm_always_fail
          @logger.info("Making create_vm method always fail")
          failed_path = File.join(@cpi_commands, 'create_vm', 'fail')
          FileUtils.mkdir_p(File.dirname(failed_path))
          File.write(failed_path, "")
        end

        def allow_create_vm_to_succeed
          @logger.info("Allowing create_vm method to succeed (removing any mandatory failures)")
          failed_path = File.join(@cpi_commands, 'create_vm', 'fail')
          FileUtils.rm(failed_path)
        end

        def next_create_vm_cmd
          @logger.info('Reading create_vm configuration')
          failed_path = File.join(@cpi_commands, 'create_vm', 'fail')
          always_path = File.join(@cpi_commands, 'create_vm', 'always')
          ip_address = File.read(always_path) if File.exists?(always_path)
          failed = File.exists?(failed_path)
          CreateVmCommand.new(ip_address, failed)
        end
      end

      class ConfigureNetworksCommand < Struct.new(:not_supported); end
      class CreateVmCommand < Struct.new(:ip_address, :failed)

        def failed?
          failed
        end
      end

      class InputsRecorder
        def initialize(base_dir, logger)
          @cpi_inputs_dir = File.join(base_dir, 'cpi_inputs')
          @logger = logger
        end

        def record(method, args)
          FileUtils.mkdir_p(@cpi_inputs_dir)
          data = {method_name: method, inputs: args}
          @logger.info("Saving input for #{method} #{data} #{ordered_file_path}")
          File.open(ordered_file_path, 'a') { |f| f.puts(JSON.dump(data)) }
        end

        def read(method_name)
          @logger.info("Reading input for #{method_name}")
          read_all.select do |invocation|
            invocation.method_name == method_name
          end
        end

        def read_all
          @logger.info("Reading all inputs: #{File.read(ordered_file_path)}")
          result = []
          File.read(ordered_file_path).split("\n").each do |request|
            data = JSON.parse(request)
            result << CpiInvocation.new(data['method_name'], data['inputs'])
          end
          result
        end

        def ordered_file_path
          File.join(@cpi_inputs_dir, 'all_requests')
        end
      end

      class VM < Struct.new(:id, :agent_id, :cloud_properties)
      end

      class VMRepo
        def initialize(running_vms_dir)
          @running_vms_dir = running_vms_dir
          FileUtils.mkdir_p(@running_vms_dir)
        end

        def load(id)
          attrs = JSON.parse(File.read(vm_file(id)))
          VM.new(id, attrs.fetch('agent_id'), attrs.fetch('cloud_properties'))
        end

        def exists?(id)
          File.exists?(vm_file(id))
        end

        def save(vm)
          serialized_vm = JSON.dump({
              'agent_id' => vm.agent_id,
              'cloud_properties' => vm.cloud_properties
            })
          File.write(vm_file(vm.id), serialized_vm)
        end

        private

        def vm_file(vm_cid)
          File.join(@running_vms_dir, vm_cid)
        end
      end

      class CpiInvocation < Struct.new(:method_name, :inputs); end
    end
  end
end
