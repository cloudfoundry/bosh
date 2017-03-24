require 'digest/sha1'
require 'fileutils'
require 'securerandom'
require 'membrane'
require 'netaddr'
require_relative '../cloud/errors'

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

        prepare
      rescue Errno::EACCES
        raise ArgumentError, "cannot create dummy cloud base directory #{@base_dir}"
      end

      CREATE_STEMCELL_SCHEMA = Membrane::SchemaParser.parse { {image_path: String, cloud_properties: Hash} }
      def create_stemcell(image_path, cloud_properties)
        validate_and_record_inputs(CREATE_STEMCELL_SCHEMA, __method__, image_path, cloud_properties)

        content = File.read(image_path)
        data = YAML.load(content)
        data.merge!('image' => image_path)
        stemcell_id = ::Digest::SHA1.hexdigest(content)

        File.write(stemcell_file(stemcell_id), YAML.dump(data))
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
        @logger.debug('Dummy: create_vm')
        validate_and_record_inputs(CREATE_VM_SCHEMA, __method__, agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)

        ips = []
        cmd = commands.next_create_vm_cmd

        if cmd.failed?
          raise Bosh::Clouds::CloudError.new('Creating vm failed')
        end

        networks.each do |network_name, network|
          if network['type'] != 'dynamic'
            ips << { 'network' => network_name, 'ip' => network.fetch('ip') }
          else
            if cmd.ip_address
              ip_address = cmd.ip_address
            elsif cloud_properties['az_name']
              ip_address = cmd.ip_address_for_az(cloud_properties['az_name'])
            else
              ip_address =  NetAddr::CIDRv4.new(rand(0..4294967295)).ip #collisions?
            end

            if ip_address
              ips << { 'network' => network_name, 'ip' => ip_address }
              write_agent_default_network(agent_id, ip_address)
            end
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
            env: env,
            mbus: @options['nats'],
          })

        agent_pid = spawn_agent_process(agent_id, cloud_properties['legacy_agent_path'])
        vm = VM.new(agent_pid.to_s, agent_id, cloud_properties, ips)

        @vm_repo.save(vm)

        vm.id
      end

      DELETE_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def delete_vm(vm_cid)
        validate_and_record_inputs(DELETE_VM_SCHEMA, __method__, vm_cid)
        commands.wait_for_unpause_delete_vms
        detach_disks_attached_to_vm(vm_cid)
        agent_pid = vm_cid.to_i
        Process.kill('KILL', agent_pid)

          # rubocop:disable HandleExceptions
      rescue Errno::ESRCH
        # rubocop:enable HandleExceptions
      ensure
        free_ips(vm_cid)
        FileUtils.rm_rf(File.join(@base_dir, 'running_vms', vm_cid))
      end

      REBOOT_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def reboot_vm(vm_cid)
        validate_and_record_inputs(__method__, vm_cid)
        raise NotImplemented, 'Dummy CPI does not implement reboot_vm'
      end

      HAS_VM_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String} }
      def has_vm(vm_cid)
        validate_and_record_inputs(HAS_VM_SCHEMA, __method__, vm_cid)
        @vm_repo.exists?(vm_cid)
      end

      HAS_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String} }
      def has_disk(disk_id)
        validate_and_record_inputs(HAS_DISK_SCHEMA, __method__, disk_id)
        File.exists?(disk_file(disk_id))
      end

      ATTACH_DISK_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, disk_id: String} }
      def attach_disk(vm_cid, disk_id)
        validate_and_record_inputs(ATTACH_DISK_SCHEMA, __method__, vm_cid, disk_id)
        if disk_attached?(disk_id)
          raise "#{disk_id} is already attached to an instance"
        end
        file = attachment_file(vm_cid, disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)

        @logger.debug("Attached disk: '#{disk_id}' to vm: '#{vm_cid}' at attachment file: #{file}")

        agent_id = agent_id_for_vm_id(vm_cid)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'][disk_id] = 'attached'
        write_agent_settings(agent_id, settings)
      end

      DETACH_DISK_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, disk_id: String} }
      def detach_disk(vm_cid, disk_id)
        validate_and_record_inputs(DETACH_DISK_SCHEMA, __method__, vm_cid, disk_id)
        unless disk_attached_to_vm?(vm_cid, disk_id)
          raise Bosh::Clouds::DiskNotAttached, "#{disk_id} is not attached to instance #{vm_cid}"
        end
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
        disk_info = JSON.generate({size: size, cloud_properties: cloud_properties, vm_locality: vm_locality})
        File.write(file, disk_info)
        disk_id
      end

      DELETE_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String} }
      def delete_disk(disk_id)
        validate_and_record_inputs(DELETE_DISK_SCHEMA, __method__, disk_id)
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

      SET_DISK_METADATA_SCHEMA = Membrane::SchemaParser.parse { {disk_cid: String, metadata: Hash} }
      def set_disk_metadata(disk_cid, metadata)
        validate_and_record_inputs(SET_DISK_METADATA_SCHEMA, __method__, disk_cid, metadata)
      end

      # Additional Dummy test helpers

      def prepare
        FileUtils.mkdir_p(@base_dir)
      end

      def reset
        FileUtils.rm_rf(@base_dir)
        prepare
      end

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

      def all_stemcells
        files = Dir.entries(@base_dir).select { |file| file.match /stemcell_./ }

        Dir.chdir(@base_dir) do
          [].tap do |results|
            files.each do |file|
              # data --> [{ 'name' => 'ubuntu-stemcell', 'version': '1', 'image' => <image path> }]
              data = YAML.load(File.read(file))
              results << { 'id' => file.sub(/^stemcell_/, '') }.merge(data)
            end
          end.sort { |a, b| a[:version].to_i <=> b[:version].to_i }
        end
      end

      def latest_stemcell
        all_stemcells.last
      end

      def all_snapshots
        if File.exists?(snapshot_file(''))
          Dir.glob(snapshot_file('*'))
        else
          []
        end
      end

      def all_ips
        Dir.glob(File.join(@base_dir, 'dummy_cpi_networks', '*'))
          .reject { |path| File.directory?(path) }
          .map { |path| File.basename(path) }
      end

      def agent_dir_for_vm_cid(vm_cid)
        agent_id = agent_id_for_vm_id(vm_cid)
        agent_base_dir(agent_id)
      end

      def disk_attached_to_vm?(vm_cid, disk_id)
        File.exist?(attachment_file(vm_cid, disk_id))
      end

      def current_apply_spec_for_vm(vm_cid)
        agent_base_dir = agent_dir_for_vm_cid(vm_cid)
        spec_file = File.join(agent_base_dir, 'bosh', 'spec.json')
        JSON.parse(File.read(spec_file))
      end

      def attached_disk_infos(vm_cid)
        agent_id = agent_id_for_vm_id(vm_cid)
        settings = read_agent_settings(agent_id)
        return [] unless settings.has_key?('disks') && settings['disks'].has_key?('persistent')

        settings['disks']['persistent'].inject([]) do |memo, disk_attachment|
          disk_cid = disk_attachment[0]
          device_path = disk_attachment[1]

          disk_info_hash = JSON.parse(File.read(disk_file(disk_cid)))
          disk_info_hash['disk_cid'] = disk_cid
          disk_info_hash['device_path'] = device_path

          memo << disk_info_hash
        end
      end

      def spawn_agent_process(agent_id, legacy_agent_path = nil)
        root_dir = File.join(agent_base_dir(agent_id), 'root_dir')
        FileUtils.mkdir_p(File.join(root_dir, 'etc', 'logrotate.d'))

        agent_cmd = agent_cmd(agent_id, legacy_agent_path)
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

      private

      def allocate_ips(ips)
        ips.each do |ip|
          begin
            network_dir = File.join(@base_dir, 'dummy_cpi_networks')
            FileUtils.makedirs(network_dir)
            open(File.join(network_dir, ip['ip']), File::WRONLY|File::CREAT|File::EXCL).close
          rescue Errno::EEXIST
            # at this point we should actually free all the IPs we successfully allocated before the collision,
            # but in practice the tests only feed in one IP per VM so that cleanup code would never be exercised
            raise "IP Address #{ip['ip']} in network '#{ip['network']}' is already in use"
          end
        end
      end

      def free_ips(vm_cid)
        return unless @vm_repo.exists?(vm_cid)
        vm = @vm_repo.load(vm_cid)
        vm.ips.each do |ip|
          FileUtils.rm_rf(File.join(@base_dir, 'dummy_cpi_networks', ip['ip']))
        end
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

      def agent_cmd(agent_id, legacy_agent_path)
        if legacy_agent_path.nil?
          go_agent_exe =  File.expand_path('../../../../go/src/github.com/cloudfoundry/bosh-agent/out/bosh-agent', __FILE__)
        else
          go_agent_exe = legacy_agent_path
        end

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

      def disk_attached?(disk_id)
        File.exist?(attachment_path(disk_id))
      end

      def detach_disks_attached_to_vm(vm_cid)
        @logger.debug("Detaching disks for vm #{vm_cid}")
        Dir.glob(attachment_file(vm_cid, '*')) do |file_path|
          @logger.debug("Detaching found attachment #{file_path}")
          FileUtils.rm_rf(File.dirname(file_path))
        end
      end

      def attachment_file(vm_cid, disk_id)
        File.join(attachment_path(disk_id), vm_cid)
      end

      def attachment_path(disk_id)
        File.join(@base_dir, 'attachments', disk_id)
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
      class CommandTransport
        def initialize(base_dir, logger)
          @cpi_commands = File.join(base_dir, 'cpi_commands')
          @logger = logger
        end

        def pause_delete_vms
          @logger.debug('Pausing delete_vms')
          path = File.join(@cpi_commands, 'pause_delete_vms')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')
        end

        def unpause_delete_vms
          @logger.debug('Unpausing delete_vms')
          FileUtils.rm_rf File.join(@cpi_commands, 'pause_delete_vms')
          FileUtils.rm_rf File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
        end

        def wait_for_delete_vms
          @logger.debug('Wait for delete_vms')
          path = File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
          sleep(0.1) until File.exists?(path)
        end

        def wait_for_unpause_delete_vms
          path = File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')

          path = File.join(@cpi_commands, 'pause_delete_vms')
          if File.exists?(path)
            @logger.debug('Wait for unpausing delete_vms')
          end
          sleep(0.1) while File.exists?(path)
        end

        def make_create_vm_always_use_dynamic_ip(ip_address)
          @logger.debug("Making create_vm method to set ip address #{ip_address}")
          FileUtils.mkdir_p(File.dirname(always_path))
          File.write(always_path, ip_address)
        end

        def set_dynamic_ips_for_azs(az_to_ips)
          @logger.debug("Making create_vm method to set #{az_to_ips.inspect}")
          FileUtils.mkdir_p(File.dirname(azs_path))
          File.write(azs_path, JSON.generate(az_to_ips))
        end

        def make_create_vm_always_fail
          @logger.debug('Making create_vm method always fail')
          FileUtils.mkdir_p(File.dirname(failed_path))
          File.write(failed_path, '')
        end

        def allow_create_vm_to_succeed
          @logger.debug('Allowing create_vm method to succeed (removing any mandatory failures)')
          FileUtils.rm(failed_path)
        end

        def next_create_vm_cmd
          @logger.debug('Reading create_vm configuration')
          ip_address = File.read(always_path) if File.exists?(always_path)
          azs_to_ip = File.exists?(azs_path) ? JSON.load(File.read(azs_path)) : {}
          failed = File.exists?(failed_path)
          CreateVmCommand.new(ip_address, azs_to_ip, failed)
        end

        private

        def azs_path
          File.join(@cpi_commands, 'create_vm', 'az_ips')
        end

        def always_path
          File.join(@cpi_commands, 'create_vm', 'always')
        end

        def failed_path
          File.join(@cpi_commands, 'create_vm', 'fail')
        end
      end

      class ConfigureNetworksCommand < Struct.new(:not_supported); end
      class CreateVmCommand
        attr_reader :ip_address, :failed

        def initialize(ip_address, azs_to_ip, failed)
          @ip_address = ip_address
          @azs_to_ip = azs_to_ip
          @failed = failed
        end

        def ip_address_for_az(az_name)
          @azs_to_ip[az_name]
        end

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
          @logger.debug("Saving input for #{method} <redacted> #{ordered_file_path}")
          File.open(ordered_file_path, 'a') { |f| f.puts(JSON.dump(data)) }
        end

        def read(method_name)
          @logger.debug("Reading input for #{method_name}")
          read_all.select do |invocation|
            invocation.method_name == method_name
          end
        end

        def read_all
          @logger.debug("Reading all inputs: #{File.read(ordered_file_path)}")
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

      class VM < Struct.new(:id, :agent_id, :cloud_properties, :ips)
      end

      class VMRepo
        def initialize(running_vms_dir)
          @running_vms_dir = running_vms_dir
          FileUtils.mkdir_p(@running_vms_dir)
        end

        def load(id)
          attrs = JSON.parse(File.read(vm_file(id)))
          VM.new(id, attrs.fetch('agent_id'), attrs.fetch('cloud_properties'), attrs.fetch('ips'))
        end

        def exists?(id)
          File.exists?(vm_file(id))
        end

        def save(vm)
          serialized_vm = JSON.dump({
              'agent_id' => vm.agent_id,
              'cloud_properties' => vm.cloud_properties,
              'ips' => vm.ips,
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
