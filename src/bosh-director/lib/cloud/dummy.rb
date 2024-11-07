require 'digest/sha1'
require 'fileutils'
require 'securerandom'
require 'membrane'
require_relative '../cloud/errors'

module Bosh
  module Clouds
    class Dummy
      class NotImplemented < StandardError; end

      attr_reader :commands
      attr_accessor :options

      def initialize(options, context, api_version)
        @options = options
        @context = context
        @api_version = api_version
        @stemcell_api_version = options.fetch('api_version', nil)

        @supported_formats = context['formats'] || ['dummy']
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
        @inputs_recorder = InputsRecorder.new(@base_dir, @logger, @context)

        prepare
      rescue Errno::EACCES
        raise ArgumentError, "cannot create dummy cloud base directory #{@base_dir}"
      end

      CREATE_STEMCELL_SCHEMA = Membrane::SchemaParser.parse { {image_path: String, cloud_properties: Hash} }
      def create_stemcell(image_path, cloud_properties)
        validate_and_record_inputs(CREATE_STEMCELL_SCHEMA, __method__, image_path, cloud_properties)

        content = File.read(image_path)
        data = YAML.load(content, aliases: true)
        data.merge!('image' => image_path)
        stemcell_id = SecureRandom.uuid

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

      def create_vm(agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)
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
              ip_address =  IPAddr.new(rand(0..IPAddr::IN4MASK), Socket::AF_INET).to_string
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

        agent_process_agent_id = agent_id
        if commands.create_vm_unresponsive_agent ||
           agent_id == commands.unresponsive_agent_agent_id
          agent_process_agent_id = 'unresponsive-agent-fake-id-' + SecureRandom.uuid
        end

        agent_pid = spawn_agent_process(agent_process_agent_id, cloud_properties['legacy_agent_path'])
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
        raise Bosh::Clouds::VMNotFound if commands.raise_vmnotfound
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

      def info
        record_inputs(__method__, nil)
        {
          stemcell_formats: @supported_formats,
        }.tap do |response|
          response['api_version'] = @api_version unless @api_version.nil?
        end
      end

      HAS_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String} }
      def has_disk(disk_id)
        validate_and_record_inputs(HAS_DISK_SCHEMA, __method__, disk_id)
        File.exist?(disk_file(disk_id))
      end

      ATTACH_DISK_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, disk_id: String} }
      def attach_disk(vm_cid, disk_id)
        validate_and_record_inputs(ATTACH_DISK_SCHEMA, __method__, vm_cid, disk_id)

        raise Bosh::Clouds::NotImplemented, 'Bosh::Clouds::NotImplemented' if commands.raise_attach_disk_not_implemented

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

        raise Bosh::Clouds::NotImplemented, 'Bosh::Clouds::NotImplemented' if commands.raise_detach_disk_not_implemented

        unless disk_attached_to_vm?(vm_cid, disk_id)
          raise Bosh::Clouds::DiskNotAttached, "#{disk_id} is not attached to instance #{vm_cid}"
        end
        FileUtils.rm_rf(attachment_path(disk_id))

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

      CREATE_NETWORK_SCHEMA = Membrane::SchemaParser.parse { { subnet_definition: Hash } }
      def create_network(subnet_definition)
        validate_and_record_inputs(CREATE_NETWORK_SCHEMA, __method__, subnet_definition)

        raise subnet_definition['cloud_properties']['error'] if subnet_definition['cloud_properties'].key?('error')

        network_id = SecureRandom.hex
        file = network_file(network_id)
        FileUtils.mkdir_p(File.dirname(file))
        network_info = JSON.generate(subnet_definition)
        File.write(file, network_info)
        addr_properties = {}
        if subnet_definition.key?('netmask_bits')
          addr_properties['range'] = '192.168.10.0/24'
          addr_properties['gateway'] = '192.168.10.1'
          addr_properties['reserved'] = ['192.168.10.2']
        end

        [network_id, addr_properties, { name: network_id }]
      end

      DELETE_NETWORK_SCHEMA = Membrane::SchemaParser.parse { { network_id: String } }
      def delete_network(network_id)
        validate_and_record_inputs(DELETE_NETWORK_SCHEMA, __method__, network_id)
        FileUtils.rm(network_file(network_id))
      end

      SNAPSHOT_DISK_SCHEMA = Membrane::SchemaParser.parse { { disk_id: String, metadata: Hash } }
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

      RESIZE_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String, new_size: Integer } }
      def resize_disk(disk_id, new_size)
        validate_and_record_inputs(RESIZE_DISK_SCHEMA, __method__, disk_id, new_size)

        raise Bosh::Clouds::NotImplemented, 'Bosh::Clouds::NotImplemented' if commands.raise_resize_disk_not_implemented

        disk_info_file = disk_file(disk_id)
        disk_info = JSON.parse(File.read(disk_info_file))
        disk_info['size'] = new_size
        File.write(disk_info_file, JSON.generate(disk_info))
      end

      UPDATE_DISK_SCHEMA = Membrane::SchemaParser.parse { {disk_id: String, size: Integer, cloud_properties: Hash} }
      def update_disk(disk_id, new_size, cloud_properties)
        validate_and_record_inputs(UPDATE_DISK_SCHEMA, __method__, disk_id, new_size, cloud_properties)

        raise Bosh::Clouds::NotImplemented, 'Bosh::Clouds::NotImplemented' if commands.raise_update_disk_not_implemented

        disk_info_file = disk_file(disk_id)
        disk_info = JSON.parse(File.read(disk_info_file))
        disk_info['size'] = new_size
        disk_info['cloud_properties'] = cloud_properties
        File.write(disk_info_file, JSON.generate(disk_info))
      end

      SET_VM_METADATA_SCHEMA = Membrane::SchemaParser.parse { {vm_cid: String, metadata: Hash} }
      def set_vm_metadata(vm_cid, metadata)
        raise 'Set VM metadata failed!!!' if commands.set_vm_metadata_should_fail?
        validate_and_record_inputs(SET_VM_METADATA_SCHEMA, __method__, vm_cid, metadata)
      end

      SET_DISK_METADATA_SCHEMA = Membrane::SchemaParser.parse { {disk_cid: String, metadata: Hash} }
      def set_disk_metadata(disk_cid, metadata)
        validate_and_record_inputs(SET_DISK_METADATA_SCHEMA, __method__, disk_cid, metadata)
      end

      CALCULATE_VM_CLOUD_PROPERTIES_SCHEMA = Membrane::SchemaParser.parse { { vm_resources: {'ram' => Integer, 'cpu' => Integer, 'ephemeral_disk_size' => Integer} } }
      def calculate_vm_cloud_properties(vm_resources)
        validate_and_record_inputs(
          CALCULATE_VM_CLOUD_PROPERTIES_SCHEMA,
          __method__,
          vm_resources
        )
        instance_type = @context['cvcpkey'].nil? ? 'dummy' : @context['cvcpkey']
        {
          instance_type: instance_type,
          cpu: vm_resources['cpu'],
          ram: vm_resources['ram'],
          ephemeral_disk: { size: vm_resources['ephemeral_disk_size'] }
        }
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

      def network_cids
        # Shuffle so that no one relies on the order of networks
        Dir.glob(network_file('*')).map { |network| File.basename(network) }.shuffle
      end

      def kill_agents
        vm_cids.each do |agent_pid|
          kill_process(agent_pid)
        end
      end

      def kill_process(agent_pid)
        Process.kill('KILL', agent_pid.to_i)
        # rubocop:disable HandleExceptions
      rescue Errno::ESRCH
        # rubocop:enable HandleExceptions
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
        files = Dir.entries(@base_dir).select { |file| file.match(/stemcell_./) }

        Dir.chdir(@base_dir) do
          [].tap do |results|
            files.each do |file|
              # data --> [{ 'name' => 'ubuntu-stemcell', 'version': '1', 'image' => <image path> }]
              data = YAML.load(File.read(file), aliases: true)
              results << { 'id' => file.sub(/^stemcell_/, '') }.merge(data)
            end
          end.sort { |a, b| a[:version].to_i <=> b[:version].to_i }
        end
      end

      def latest_stemcell
        all_stemcells.last
      end

      def all_snapshots
        if File.exist?(snapshot_file(''))
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

        begin
          Process.getpgid(agent_pid)
        rescue => e
          raise RuntimeError, "Expected agent to be running: #{e}"
        end

        Process.detach(agent_pid)

        agent_pid
      end

      private

      def allocate_ips(ips)
        ips.each do |ip|
          begin
            network_dir = File.join(@base_dir, 'dummy_cpi_networks')
            FileUtils.makedirs(network_dir)
            File.open(File.join(network_dir, ip['ip']), File::WRONLY|File::CREAT|File::EXCL).close
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
          go_agent_exe =  File.expand_path('../../../../bosh-agent/out/bosh-agent', __FILE__)
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
                }]
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

      def network_file(network_id)
        File.join(@base_dir, 'networks', network_id)
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
          sleep(0.1) until File.exist?(path)
        end

        def wait_for_unpause_delete_vms
          path = File.join(@cpi_commands, 'wait_for_unpause_delete_vms')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'marker')

          path = File.join(@cpi_commands, 'pause_delete_vms')
          if File.exist?(path)
            @logger.debug('Wait for unpausing delete_vms')
          end
          sleep(0.1) while File.exist?(path)
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
          ip_address = File.read(always_path) if File.exist?(always_path)
          azs_to_ip = File.exist?(azs_path) ? JSON.load(File.read(azs_path)) : {}
          failed = File.exist?(failed_path)
          CreateVmCommand.new(ip_address, azs_to_ip, failed)
        end

        def make_set_vm_metadata_always_fail
          @logger.debug('Making set_vm_metadata method always fail')
          FileUtils.mkdir_p(File.dirname(set_vm_metadata_path_fail_path))
          File.write(set_vm_metadata_path_fail_path, '')
        end

        def allow_set_vm_metadata_to_succeed
          @logger.debug('Allowing set_vm_metadata method to succeed (removing any mandatory failures)')
          FileUtils.rm(set_vm_metadata_path_fail_path)
        end

        def set_vm_metadata_should_fail?
          @logger.info('Reading set_vm_metadata configuration')
          File.exist?(set_vm_metadata_path_fail_path)
        end

        def make_delete_vm_to_raise_vmnotfound
          @logger.info('Making delete_vm method to raise VMNotFound exception')
          FileUtils.mkdir_p(File.dirname(raise_vmnotfound_path))
          File.write(raise_vmnotfound_path, '')
        end

        def raise_vmnotfound
          @logger.info('Reading delete_vm configuration')
          File.exist?(raise_vmnotfound_path)
        end

        def allow_detach_disk_to_succeed
          @logger.debug('Allowing detach_disk method to succeed (removing any mandatory failures)')
          FileUtils.rm(raise_detach_disk_not_implemented_path)
        end

        def make_detach_disk_to_raise_not_implemented
          @logger.info('Making detach_disk method to raise NotImplemented exception')
          FileUtils.mkdir_p(File.dirname(raise_detach_disk_not_implemented_path))
          FileUtils.touch(raise_detach_disk_not_implemented_path)
        end

        def make_create_vm_have_unresponsive_agent_for_agent_id(agent_id)
          @logger.info("Making create_vm method create with an unresponsive agent for agent_id #{agent_id}")
          FileUtils.mkdir_p(File.dirname(create_vm_unresponsive_agent_agent_id_path))
          File.write(create_vm_unresponsive_agent_agent_id_path, agent_id)
        end

        def make_create_vm_have_unresponsive_agent
          @logger.info('Making create_vm method create with an unresponsive agent')
          FileUtils.mkdir_p(File.dirname(create_vm_unresponsive_agent_path))
          FileUtils.touch(create_vm_unresponsive_agent_path)
        end

        def allow_create_vm_to_have_responsive_agent
          @logger.info('Making create_vm method create with a responsive agent')
          FileUtils.rm_f(create_vm_unresponsive_agent_agent_id_path)
          FileUtils.rm_f(create_vm_unresponsive_agent_path)
        end

        def allow_attach_disk_to_succeed
          @logger.debug('Allowing attach_disk method to succeed (removing any mandatory failures)')
          FileUtils.rm(raise_attach_disk_not_implemented_path)
        end

        def make_attach_disk_to_raise_not_implemented
          @logger.info('Making attach_disk method to raise NotImplemented exception')
          FileUtils.mkdir_p(File.dirname(raise_attach_disk_not_implemented_path))
          FileUtils.touch(raise_attach_disk_not_implemented_path)
        end

        def raise_attach_disk_not_implemented
          @logger.info('Reading attach_disk_not_implemented')
          File.exist?(raise_attach_disk_not_implemented_path)
        end

        def create_vm_unresponsive_agent
          @logger.info('Reading create_vm_unresponsive_agent')
          File.exist?(create_vm_unresponsive_agent_path)
        end

        def unresponsive_agent_agent_id
          @logger.info('Reading create_vm_unresponsive_agent_agent_id')
          File.read(create_vm_unresponsive_agent_agent_id_path)
        rescue StandardError
          false
        end

        def make_resize_disk_to_raise_not_implemented
          @logger.info('Making resize_disk method to raise NotImplemented exception')
          FileUtils.mkdir_p(File.dirname(raise_resize_disk_not_implemented_path))
          FileUtils.touch(raise_resize_disk_not_implemented_path)
        end

        def raise_detach_disk_not_implemented
          @logger.info('Reading detach_disk_not_implemented')
          File.exist?(raise_detach_disk_not_implemented_path)
        end

        def raise_resize_disk_not_implemented
          @logger.info('Reading resize_disk_not_implemented')
          File.exist?(raise_resize_disk_not_implemented_path)
        end

        def make_update_disk_to_raise_not_implemented
          @logger.info('Making update_disk method to raise NotImplemented exception')
          FileUtils.mkdir_p(File.dirname(raise_update_disk_not_implemented_path))
          FileUtils.touch(raise_update_disk_not_implemented_path)
        end

        def raise_update_disk_not_implemented
          @logger.info('Reading update_disk_not_implemented')
          File.exist?(raise_update_disk_not_implemented_path)
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

        def set_vm_metadata_path_fail_path
          File.join(@cpi_commands, 'update_vm_metadata', 'fail')
        end

        def raise_vmnotfound_path
          File.join(@cpi_commands, 'delete_vm', 'fail')
        end

        def raise_detach_disk_not_implemented_path
          File.join(@cpi_commands, 'detach_disk', 'not_implemented')
        end

        def raise_attach_disk_not_implemented_path
          File.join(@cpi_commands, 'attach_disk', 'not_implemented')
        end

        def create_vm_unresponsive_agent_path
          File.join(@cpi_commands, 'create_vm', 'unresponsive_agent')
        end

        def create_vm_unresponsive_agent_agent_id_path
          File.join(@cpi_commands, 'create_vm', 'unresponsive_agent_agent_id')
        end

        def raise_resize_disk_not_implemented_path
          File.join(@cpi_commands, 'resize_disk', 'not_implemented')
        end

        def raise_update_disk_not_implemented_path
          File.join(@cpi_commands, 'update_disk', 'not_implemented')
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
        def initialize(base_dir, logger, context)
          @cpi_inputs_dir = File.join(base_dir, 'cpi_inputs')
          @logger = logger
          @context = context
        end

        def record(method, args)
          FileUtils.mkdir_p(@cpi_inputs_dir)
          data = {method_name: method, inputs: args, context: @context}
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
            result << CpiInvocation.new(data['method_name'], data['inputs'], data['context'])
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
          File.exist?(vm_file(id))
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

      class CpiInvocation < Struct.new(:method_name, :inputs, :context); end
    end
  end
end
