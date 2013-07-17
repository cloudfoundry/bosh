# Copyright (c) 2009-2012 VMware, Inc.

require 'pp'

require "deployer"

module Bosh::Cli::Command
  class Micro < Base
    include Bosh::Deployer::Helpers

    MICRO_DIRECTOR_PORT = 25555
    DEFAULT_CONFIG_PATH = File.expand_path("~/.bosh_deployer_config")
    MICRO_BOSH_YAML = "micro_bosh.yml"

    def initialize(runner)
      super(runner)
      options[:config] ||= DEFAULT_CONFIG_PATH #hijack Cli::Config
    end

    usage "micro"
    desc  "show micro bosh sub-commands"
    def micro_help
      say("bosh micro sub-commands:")
      nl
      cmds = Bosh::Cli::Config.commands.values.find_all {|c|
        c.usage =~ /^micro/
      }
      Bosh::Cli::Command::Help.list_commands(cmds)
    end

    usage "micro deployment"
    desc  "Choose micro deployment to work with, or display current deployment"
    def micro_deployment(name=nil)
      if name
        set_current(name)
      else
        show_current
      end
    end

    def set_current(name)
      manifest_filename = find_deployment(name)

      if !File.exists?(manifest_filename)
        err "Missing manifest for #{name} (tried '#{manifest_filename}')"
      end

      manifest = load_yaml_file(manifest_filename)

      unless manifest.is_a?(Hash)
        err "Invalid manifest format"
      end

      if manifest["network"].blank?
        err "network is not defined in deployment manifest"
      end
      ip = deployer(manifest_filename).discover_bosh_ip || name

      if target
        old_director_ip = URI.parse(target).host
      else
        old_director_ip = nil
      end

      if old_director_ip != ip
        set_target(ip)
        say "#{"WARNING!".make_red} Your target has been changed to `#{target.make_red}'!"
      end

      say "Deployment set to '#{manifest_filename.make_green}'"
      config.set_deployment(manifest_filename)
      config.save
    end

    def show_current
      say(deployment ? "Current deployment is '#{deployment.make_green}'" : "Deployment not set")
    end

    usage "micro status"
    desc  "Display micro BOSH deployment status"
    def status
      stemcell_cid = deployer_state(:stemcell_cid)
      stemcell_name = deployer_state(:stemcell_name)
      vm_cid = deployer_state(:vm_cid)
      disk_cid = deployer_state(:disk_cid)
      deployment = config.deployment ? config.deployment.make_green : "not set".make_red

      say("Stemcell CID".ljust(15) + stemcell_cid)
      say("Stemcell name".ljust(15) + stemcell_name)
      say("VM CID".ljust(15) + vm_cid)
      say("Disk CID".ljust(15) + disk_cid)
      say("Micro BOSH CID".ljust(15) + Bosh::Deployer::Config.uuid)
      say("Deployment".ljust(15) + deployment)

      update_target

      target_name = target ? target.make_green : "not set".make_red
      say("Target".ljust(15) + target_name)
    end

    usage  "micro deploy"
    desc   "Deploy a micro BOSH instance to the currently selected deployment"
    option "--update", "update existing instance"
    def perform(stemcell=nil)
      update = !!options[:update]

      err "No deployment set" unless deployment

      manifest = load_yaml_file(deployment)

      if stemcell.nil?
        unless manifest.is_a?(Hash)
          err("Invalid manifest format")
        end

        stemcell = dig_hash(manifest, "resources", "cloud_properties", "image_id")

        if stemcell.nil?
          err "No stemcell provided"
        end
      end

      deployer.check_dependencies

      rel_path = deployment[/#{Regexp.escape File.join(work_dir, '')}(.*)/, 1]

      desc = "`#{rel_path.make_green}' to `#{target_name.make_green}'"

      if update
        unless deployer.exists?
          err "No existing instance to update"
        end

        confirmation = "Updating"

        method = :update_deployment
      else
        if deployer.exists?
          err "Instance exists.  Did you mean to --update?"
        end

        # make sure the user knows a persistent disk is required
        unless dig_hash(manifest, "resources", "persistent_disk")
          quit("No persistent disk configured in #{MICRO_BOSH_YAML}".make_red)
        end

        confirmation = "Deploying new"

        method = :create_deployment
      end

      confirm_deployment("#{confirmation} micro BOSH instance #{desc}")

      if is_tgz?(stemcell)
        stemcell_file = Bosh::Cli::Stemcell.new(stemcell, cache)

        say("\nVerifying stemcell...")
        stemcell_file.validate
        say("\n")

        unless stemcell_file.valid?
          err("Stemcell is invalid, please fix, verify and upload again")
        end
      end

      renderer = DeployerRenderer.new
      renderer.start
      deployer.renderer = renderer

      start_time = Time.now

      deployer.send(method, stemcell)

      renderer.finish("done")

      duration = renderer.duration || (Time.now - start_time)

      update_target

      say("Deployed #{desc}, took #{format_time(duration).make_green} to complete")
    end

    usage  "micro delete"
    desc   "Delete micro BOSH instance (including persistent disk)"
    def delete
      unless deployer.exists?
        err "No existing instance to delete"
      end

      name = deployer.state.name

      say "\nYou are going to delete micro BOSH deployment `#{name}'.\n\n" \
      "THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red

      unless confirmed?
        say "Canceled deleting deployment".make_green
        return
      end

      renderer = DeployerRenderer.new
      renderer.start
      deployer.renderer = renderer

      start_time = Time.now

      deployer.delete_deployment

      renderer.finish("done")

      duration = renderer.duration || (Time.now - start_time)

      say("Deleted deployment '#{name}', took #{format_time(duration).make_green} to complete")
    end

    usage "micro deployments"
    desc  "Show the list of deployments"
    def list
      file = File.join(work_dir, DEPLOYMENTS_FILE)
      if File.exists?(file)
        deployments = load_yaml_file(file)["instances"]
      else
        deployments = []
      end

      err("No deployments") if deployments.size == 0

      na = "n/a"

      deployments_table = table do |t|
        t.headings = [ "Name", "VM name", "Stemcell name" ]
        deployments.each do |r|
          t << [ r[:name], r[:vm_cid] || na, r[:stemcell_cid] || na  ]
        end
      end

      say("\n")
      say(deployments_table)
      say("\n")
      say("Deployments total: %d" % deployments.size)
    end

    usage "micro agent <args>"
    desc  <<-AGENT_HELP
Send agent messages

  Message Types:

    start - Start all jobs on MicroBOSH

    stop - Stop all jobs on MicroBOSH

    ping - Check to see if the agent is responding

    drain TYPE SPEC - Tell the agent to begin draining
      TYPE - One of 'shutdown', 'update' or 'status'.
      SPEC - The drain spec to use.

    state [full] - Get the state of a system
      full - Get additional information about system vitals

    list_disk - List disk CIDs mounted on the system

    migrate_disk OLD NEW - Migrate a disk
      OLD - The CID of the source disk.
      NEW - The CID of the destination disk.

    mount_disk CID - Mount a disk on the system
      CID - The cloud ID of the disk to mount.

    unmount_disk CID - Unmount a disk from the system
      CID - The cloud ID of the disk to unmount.

AGENT_HELP
    def agent(*args)
      message = args.shift
      args = args.map do |arg|
        if File.exists?(arg)
          load_yaml_file(arg)
        else
          arg
        end
      end

      say(deployer.agent.send(message.to_sym, *args).pretty_inspect)
    end

    usage "micro apply"
    desc  "Apply spec"
    def apply(spec)
      deployer.apply(Bosh::Deployer::Specification.new(load_yaml_file(spec)))
    end

    private

    def deployer(manifest_filename=nil)
      check_if_deployments_dir
      deployment_required unless manifest_filename

      if @deployer.nil?
        manifest_filename ||= deployment

        if !File.exists?(manifest_filename)
          err("Cannot find deployment manifest in `#{manifest_filename}'")
        end

        manifest = load_yaml_file(manifest_filename)

        manifest["dir"] ||= work_dir
        manifest["logging"] ||= {}
        unless manifest["logging"]["file"]
          log_file = File.join(File.dirname(manifest_filename),
                               "bosh_micro_deploy.log")
          manifest["logging"]["file"] = log_file
        end

        @deployer = Bosh::Deployer::InstanceManager.create(manifest)
      end

      @deployer
    end

    def check_if_deployments_dir
      #force the issue to maintain central bosh-deployments.yml
      if File.basename(work_dir) != "deployments"
        err "Sorry, your current directory doesn't look like deployments directory"
      end
    end

    def find_deployment(name)
      check_if_deployments_dir
      File.expand_path(File.join(work_dir, "#{name}", MICRO_BOSH_YAML))
    end

    def deployment_name
      File.basename(File.dirname(deployment))
    end

    # set new target and clear out cached values
    # does not persist the new values (set_current() does this)
    def set_target(ip)
      config.target = "https://#{ip}:#{MICRO_DIRECTOR_PORT}"
      config.target_name = nil
      config.target_version = nil
      config.target_uuid = nil
    end

    def update_target
      if deployer.exists?
        bosh_ip = deployer.discover_bosh_ip
        if URI.parse(target).host != bosh_ip
          set_current(deployment_name)
        end

        director = Bosh::Cli::Director.new(target)

        if options[:director_checks]
          begin
            status = director.get_status
          rescue Bosh::Cli::AuthError
            status = {}
          rescue Bosh::Cli::DirectorError
            err("Cannot talk to director at '#{target}', please set correct target")
          end
        else
          status = { "name" => "Unknown Director", "version" => "n/a" }
        end
      else
        status = {}
      end

      config.target_name = status["name"]
      config.target_version = status["version"]
      config.target_uuid = status["uuid"]

      config.save
    end

    def confirm_deployment(msg)
      unless confirmed?(msg)
        cancel_deployment
      end
    end

    def deployer_state(column)
      if value = deployer.state.send(column)
        value.make_green
      else
        "n/a".make_red
      end
    end

    class DeployerRenderer < Bosh::Cli::EventLogRenderer
      attr_accessor :stage, :total, :index

      DEFAULT_POLL_INTERVAL = 1

      def interval_poll
        Bosh::Cli::Config.poll_interval || DEFAULT_POLL_INTERVAL
      end

      def start
        @thread = Thread.new do
          loop do
            refresh
            sleep(interval_poll)
          end
        end
      end

      def finish(state)
        @thread.kill
        super(state)
      end

      def enter_stage(stage, total)
        @stage = stage
        @total = total
        @index = 0
      end

      def parse_event(event)
        event
      end

      def update(state, task)
        event = {
          "time"     => Time.now,
          "stage"    => @stage,
          "task"     => task,
          "tags"     => [],
          "index"    => @index+1,
          "total"    => @total,
          "state"    => state.to_s,
          "progress" => state == :finished ? 100 : 0
        }

        add_event(event)

        @index += 1 if state == :finished
      end
    end

  end
end
