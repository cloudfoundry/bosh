module Bosh::Deployer
  class InstanceManager

    DEPLOYMENTS_FILE = "bosh-deployments.yml"

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
      Config.disk_model
    end

    def instance_model
      Models::Instance
    end

    def instance_state
      instance_state = {}
      instance_state["instances"] = state.values
      if state.disk_cid
        instance_state["disks"] = disk_model[state.disk_cid].values
      end
      instance_state
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

    def create(stemcell_tgz)
      if state.vm_cid
        raise ConfigError, "VM #{state.vm_cid} already exists"
      end
      if state.stemcell_cid
        raise ConfigError, "stemcell #{state.stemcell_cid} already exists"
      end

      renderer.enter_stage("Deploy Micro BOSH", 11)

      state.stemcell_cid = create_stemcell(stemcell_tgz)
      state.stemcell_name = File.basename(stemcell_tgz, ".tgz")
      save_state

      begin
        step "Creating VM from #{state.stemcell_cid}" do
          state.vm_cid = create_vm(state.stemcell_cid)
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
      end
      delete_vm
      delete_stemcell
    end

    def update(stemcell_tgz)
      renderer.enter_stage("Prepare for update", 5)
      agent_stop
      detach_disk
      delete_vm
      delete_stemcell
      create(stemcell_tgz)
    end

    def create_stemcell(stemcell_tgz)
      Dir.mktmpdir("sc-") do |stemcell|
        step "Unpacking stemcell" do
          run_command("tar -zxf #{stemcell_tgz} -C #{stemcell}")
        end

        @apply_spec = load_apply_spec("#{stemcell}/apply_spec.yml")

        step "Uploading stemcell" do
          cloud.create_stemcell("#{stemcell}/image", {})
        end
      end
    end

    def create_vm(stemcell_cid)
      resources = Config.resources['cloud_properties']
      networks  = Config.networks
      cloud.create_vm(state.uuid, stemcell_cid, resources, networks)
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
        state.disk_cid = cloud.create_disk(Config.resources['persistent_disk'])
        save_state
      end
    end

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
        state.disk_cid = nil
        save_state
      rescue Bosh::Clouds::DiskNotFound
      end
    end

    def attach_disk(is_create=false)
      return if state.disk_cid.nil?

      cloud.attach_disk(state.vm_cid, state.disk_cid)
      save_state

      begin
        mount_disk(state.disk_cid)
      rescue
        if is_create
          logger.warn("!!! mount_disk(#{state.disk_cid}) failed !!! retrying...")
          mount_disk(state.disk_cid)
        else
          raise
        end
      end
    end

    def detach_disk
      if state.disk_cid.nil?
        raise "Error while detaching disk: unknown disk attached to instance"
      end

      unmount_disk(state.disk_cid)
      step "Detach disk" do
        cloud.detach_disk(state.vm_cid, state.disk_cid)
      end
    end

    def attach_missing_disk
      if state.disk_cid
        attach_disk(true)
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

      #XXX handle disk size change
      if state.disk_cid.nil?
        create_disk
        attach_disk(true)
      end
    end

    def update_spec(spec)
      properties = spec["properties"]

      %w{blobstore postgres director redis nats}.each do |service|
        properties[service]["address"] = bosh_ip
      end

      case Config.cloud_options["plugin"]
      when "vsphere"
        properties["vcenter"] = Config.cloud_options["properties"]["vcenters"].first.dup
        properties["vcenter"]["address"] ||= properties["vcenter"]["host"]
      else
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

    private

    def bosh_ip
      Config.networks["bosh"]["ip"]
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

      step "Delete stemcell" do
        cloud.delete_stemcell(state.stemcell_cid)
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

    def load_apply_spec(file)
      logger.info("Loading apply spec from #{file}")
      YAML.load_file(file)
    end

    def load_state(name)
      @deployments = load_deployments

      disk_model.insert_multiple(@deployments["disks"])
      instance_model.insert_multiple(@deployments["instances"])

      @state = instance_model.find(:name => name)
      if @state.nil?
        @state = instance_model.new
        @state.uuid = UUIDTools::UUID.random_create.to_s
        @state.name = name
        @state.save
      end
    end

    def save_state
      state.save
      @deployments["instances"] = instance_model.map { |instance| instance.values }
      @deployments["disks"] = disk_model.map { |disk| disk.values }

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
