# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer
  class InstanceManager

    include Helpers

    attr_reader :state
    attr_accessor :renderer

    class LoggerRenderer
      attr_accessor :stage, :total, :index

      def initialize
        enter_stage("Deployer", 0)
      end

      def enter_stage(stage, total)
        @stage = stage
        @total = total
        @index = 0
      end

      def update(state, task)
        Config.logger.info("#{@stage} - #{state} #{task}")
        @index += 1 if state == :finished
      end
    end

    class << self

      include Helpers

      def create(config)
        plugin = cloud_plugin(config)

        begin
          require "deployer/instance_manager/#{plugin}"
        rescue LoadError
          raise Error, "Could not find Provider Plugin: #{plugin}"
        end
        Bosh::Deployer::InstanceManager.const_get(plugin.capitalize).new(config)
      end

    end

    def initialize(config)
      Config.configure(config)

      @state_yml = File.join(config["dir"], DEPLOYMENTS_FILE)
      load_state(config["name"])

      Config.uuid = state.uuid

      @renderer = LoggerRenderer.new
    end

    def cloud
      Config.cloud
    end

    def agent
      Config.agent
    end

    def logger
      Config.logger
    end

    def disk_model
      nil
    end

    def instance_model
      Models::Instance
    end

    def exists?
      state.vm_cid != nil
    end

    def step(task)
      renderer.update(:started, task)
      result = yield
      renderer.update(:finished, task)
      result
    end

    def start
    end

    def stop
    end

    def with_lifecycle
      start
      yield
    ensure
      stop
    end

    def create_deployment(stemcell_tgz)
      with_lifecycle do
        create(stemcell_tgz)
      end
    end

    def update_deployment(stemcell_tgz)
      with_lifecycle do
        update(stemcell_tgz)
      end
    end

    def delete_deployment
      with_lifecycle do
        destroy
      end
    end

    def create(stemcell_tgz)
      if state.vm_cid
        raise ConfigError, "VM #{state.vm_cid} already exists"
      end
      if state.stemcell_cid && state.stemcell_cid != state.stemcell_name
        raise ConfigError, "stemcell #{state.stemcell_cid} already exists"
      end

      renderer.enter_stage("Deploy Micro BOSH", 11)

      state.stemcell_cid = create_stemcell(stemcell_tgz)
      state.stemcell_name = File.basename(stemcell_tgz, ".tgz")
      save_state

      begin
        step "Creating VM from #{state.stemcell_cid}" do
          state.vm_cid = create_vm(state.stemcell_cid)
          discover_bosh_ip
        end
        save_state
      rescue => e
        delete_stemcell
        raise e
      end

      step "Waiting for the agent" do
        wait_until_agent_ready
      end

      step "Updating persistent disk" do
        update_persistent_disk
      end

      unless @apply_spec
        step "Fetching apply spec" do
          @apply_spec = agent.release_apply_spec
        end
      end

      apply(@apply_spec)

      step "Waiting for the director" do
        wait_until_director_ready
      end
    end

    def destroy
      renderer.enter_stage("Delete micro BOSH", 6)
      agent_stop
      if state.disk_cid
        delete_disk(state.disk_cid, state.vm_cid)
        state.disk_cid = nil
        save_state
      end
      delete_vm
      delete_stemcell
    end

    def update(stemcell_tgz)
      renderer.enter_stage("Prepare for update", 5)
      agent_stop
      detach_disk(state.disk_cid)
      delete_vm
      # Do we always want to delete the stemcell?
      # What if we are redeploying to the same stemcell version just so
      # we can upgrade to a bigger persistent disk.
      # Perhaps use "--preserve" to skip the delete?
      delete_stemcell
      create(stemcell_tgz)
    end

    def create_stemcell(stemcell_tgz)
      unless is_tgz?(stemcell_tgz)
        step "Using existing stemcell" do
        end

        return stemcell_tgz
      end

      Dir.mktmpdir("sc-") do |stemcell|
        step "Unpacking stemcell" do
          run_command("tar -zxf #{stemcell_tgz} -C #{stemcell}")
        end

        @apply_spec = load_apply_spec(stemcell)

        # load properties from stemcell manifest
        properties = load_stemcell_manifest(stemcell)

        # override with values from the deployment manifest
        override = Config.cloud_options["properties"]["stemcell"]
        properties["cloud_properties"].merge!(override) if override

        step "Uploading stemcell" do
          cloud.create_stemcell("#{stemcell}/image", properties["cloud_properties"])
        end
      end
    end

    def create_vm(stemcell_cid)
      resources = Config.resources['cloud_properties']
      networks  = Config.networks
      env = Config.env
      cloud.create_vm(state.uuid, stemcell_cid, resources, networks, nil, env)
    end

    def mount_disk(disk_cid)
      step "Mount disk" do
        agent.run_task(:mount_disk, disk_cid.to_s)
      end
    end

    def unmount_disk(disk_cid)
      step "Unmount disk" do
        if disk_info.include?(disk_cid)
          agent.run_task(:unmount_disk, disk_cid.to_s)
        else
          logger.error("not unmounting %s as it doesn't belong to me: %s" %
            [disk_cid, disk_info])
        end
      end
    end

    def migrate_disk(src_disk_cid, dst_disk_cid)
      step "Migrate disk" do
        agent.run_task(:migrate_disk, src_disk_cid.to_s, dst_disk_cid.to_s)
      end
    end

    def disk_info
      return @disk_list if @disk_list
      @disk_list = agent.list_disk
    end

    def create_disk
      step "Create disk" do
        size = Config.resources['persistent_disk']
        state.disk_cid = cloud.create_disk(size, state.vm_cid)
        save_state
      end
    end

    # it is up to the caller to save/update disk state info
    def delete_disk(disk_cid, vm_cid)
      unmount_disk(disk_cid)

      begin
        step "Detach disk" do
          cloud.detach_disk(vm_cid, disk_cid) if vm_cid
        end
      rescue Bosh::Clouds::DiskNotAttached
      end

      begin
        step "Delete disk" do
          cloud.delete_disk(disk_cid)
        end
      rescue Bosh::Clouds::DiskNotFound
      end
    end

    # it is up to the caller to save/update disk state info
    def attach_disk(disk_cid, is_create=false)
      return unless disk_cid

      cloud.attach_disk(state.vm_cid, disk_cid)
      mount_disk(disk_cid)
    end

    def detach_disk(disk_cid)
      unless disk_cid
        raise "Error while detaching disk: unknown disk attached to instance"
      end

      unmount_disk(disk_cid)
      step "Detach disk" do
        cloud.detach_disk(state.vm_cid, disk_cid)
      end
    end

    def attach_missing_disk
      if state.disk_cid
        attach_disk(state.disk_cid, true)
      end
    end

    def check_persistent_disk
      return if state.disk_cid.nil?
      agent_disk_cid = disk_info.first
      if agent_disk_cid != state.disk_cid
        raise "instance #{state.vm_cid} has invalid disk: Agent reports #{agent_disk_cid} while deployer's record shows #{state.disk_cid}"
      end
    end

    def update_persistent_disk
      attach_missing_disk
      check_persistent_disk

      if state.disk_cid.nil?
        create_disk
        attach_disk(state.disk_cid, true)
      elsif persistent_disk_changed?
        size = Config.resources['persistent_disk']

        # save a reference to the old disk
        old_disk_cid = state.disk_cid

        # create a new disk and attach it
        new_disk_cid = cloud.create_disk(size, state.vm_cid)
        attach_disk(new_disk_cid, true)

        # migrate data (which mounts the disks)
        migrate_disk(old_disk_cid, new_disk_cid)

        # replace the old with the new in the state file
        state.disk_cid = new_disk_cid

        # delete the old disk
        delete_disk(old_disk_cid, state.vm_cid)
      end
    ensure
      save_state
    end

    def update_spec(spec)
      properties = spec["properties"]

      # set the director name to what is specified in the micro_bosh.yml
      if Config.name
        properties["director"] = {} unless properties["director"]
        properties["director"]["name"] = Config.name
      end

      # blobstore and nats need to use an elastic IP (if available),
      # as when the micro bosh instance is re-created during a
      # deployment, it might get a new private IP
      %w{blobstore nats}.each do |service|
        update_agent_service_address(properties, service, bosh_ip)
      end

      services = %w{postgres director redis blobstore nats aws_registry
                    openstack_registry}
      services.each do |service|
        update_service_address(properties, service, service_ip)
      end

      spec
    end

    def apply(spec)
      agent_stop

      step "Applying micro BOSH spec" do
        agent.run_task(:apply, update_spec(spec.dup))
      end

      agent_start
    end

    def discover_bosh_ip
      bosh_ip
    end

    def service_ip
      bosh_ip
    end

    private

    # update the agent service section from the contents of the apply_spec
    def update_agent_service_address(properties, service, address)
      if Config.agent_properties
        agent = properties["agent"] ||= {}
        svc = agent[service] ||= {}
        svc["address"] = address

        if override = Config.agent_properties[service]
          svc.merge!(override)
        end
      end
    end

    def update_service_address(properties, service, address)
      return unless properties[service]
      properties[service]["address"] = address

      if override = Config.spec_properties[service]
        properties[service].merge!(override)
      end
    end

    def bosh_ip
      Config.bosh_ip
    end

    def agent_stop
      step "Stopping agent services" do
        begin
          agent.run_task(:stop)
        rescue
        end
      end
    end

    def agent_start
      step "Starting agent services" do
        agent.run_task(:start)
      end
    end

    def wait_until_ready
      timeout_time = Time.now.to_f + (60 * 5)
      begin
        yield
        sleep 0.5
      rescue Bosh::Agent::Error, Errno::ECONNREFUSED => e
        if timeout_time - Time.now.to_f > 0
          retry
        else
          raise e
        end
      end
    end

    def wait_until_agent_ready #XXX >> agent_client
      wait_until_ready { agent.ping }
    end

    def wait_until_director_ready
      port = @apply_spec["properties"]["director"]["port"]
      url = "http://#{bosh_ip}:#{port}/info"
      wait_until_ready do
        info = Yajl::Parser.parse(HTTPClient.new.get(url).body)
        logger.info("Director is ready: #{info.inspect}")
      end
    end

    def delete_stemcell
      unless state.stemcell_cid
        raise ConfigError, "Cannot find existing stemcell"
      end

      if state.stemcell_cid == state.stemcell_name
        step "Preserving stemcell" do
        end
      else
        step "Delete stemcell" do
          cloud.delete_stemcell(state.stemcell_cid)
        end
      end

      state.stemcell_cid = nil
      state.stemcell_name = nil
      save_state
    end

    def delete_vm
      unless state.vm_cid
        raise ConfigError, "Cannot find existing VM"
      end
      step "Delete VM" do
        cloud.delete_vm(state.vm_cid)
      end
      state.vm_cid = nil
      save_state
    end

    def load_deployments
      if File.exists?(@state_yml)
        logger.info("Loading existing deployment data from: #{@state_yml}")
        YAML.load_file(@state_yml)
      else
        logger.info("No existing deployments found (will save to #{@state_yml})")
        { "instances" => [], "disks" => [] }
      end
    end

    def load_apply_spec(dir)
      load_spec("#{dir}/apply_spec.yml") do
        raise "this isn't a micro bosh stemcell - apply_spec.yml missing"
      end
    end

    def load_stemcell_manifest(dir)
      load_spec("#{dir}/stemcell.MF") do
        raise "this isn't a stemcell - stemcell.MF missing"
      end
    end

    def load_spec(file)
      yield unless File.exist?(file)
      logger.info("Loading yaml from #{file}")
      YAML.load_file(file)
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    def load_state(name)
      @deployments = load_deployments

      disk_model.insert_multiple(@deployments["disks"]) if disk_model
      instance_model.insert_multiple(@deployments["instances"])

      @state = instance_model.find(:name => name)
      if @state.nil?
        @state = instance_model.new
        @state.uuid = "bm-#{generate_unique_name}"
        @state.name = name
        @state.save
      else
        discover_bosh_ip
      end
    end

    def save_state
      state.save
      @deployments["instances"] = instance_model.map { |instance| instance.values }
      @deployments["disks"] = disk_model.map { |disk| disk.values } if disk_model

      File.open(@state_yml, "w") do |file|
        file.write(YAML.dump(@deployments))
      end
    end

    def run_command(command)
      output = `#{command} 2>&1`
      if $?.exitstatus != 0
        $stderr.puts output
        raise "'#{command}' failed with exit status=#{$?.exitstatus} [#{output}]"
      end
    end

  end
end
