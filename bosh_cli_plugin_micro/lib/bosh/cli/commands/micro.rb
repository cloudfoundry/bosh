require 'pp'
require 'bosh/deployer'
require 'bosh/deployer/deployer_renderer'
require 'bosh/stemcell'
require 'bosh/stemcell/archive'

module Bosh::Cli::Command
  class Micro < Base
    MICRO_DIRECTOR_PORT = 25555
    DEFAULT_CONFIG_PATH = File.expand_path('~/.bosh_deployer_config')
    MICRO_BOSH_YAML = 'micro_bosh.yml'

    def initialize(runner)
      super(runner)
      options[:config] ||= DEFAULT_CONFIG_PATH # hijack Cli::Config
    end

    usage 'micro'
    desc 'show micro bosh sub-commands'
    def micro_help
      say('bosh micro sub-commands:')
      nl
      cmds = Bosh::Cli::Config.commands
      cmds = cmds.values.find_all { |c| c.usage =~ /^micro/ }
      Bosh::Cli::Command::Help.list_commands(cmds)
    end

    usage 'micro deployment'
    desc 'Choose micro deployment to work with, or display current deployment'
    def micro_deployment(name = nil)
      if name
        set_current(name)
      else
        show_current
      end
    end

    # rubocop:disable MethodLength
    def set_current(name)
      manifest_filename = find_deployment(name)

      unless File.exists?(manifest_filename)
        err "Missing manifest for #{name} (tried '#{manifest_filename}')"
      end

      manifest = load_yaml_file(manifest_filename)

      unless manifest.is_a?(Hash)
        err 'Invalid manifest format'
      end

      if manifest['network'].blank?
        err 'network is not defined in deployment manifest'
      end
      ip = deployer(manifest_filename).discover_bosh_ip || name

      if target
        old_director_ip = URI.parse(target).host
      else
        old_director_ip = nil
      end

      if old_director_ip != ip
        set_target(ip)
        say "#{'WARNING!'.make_red} Your target has been changed to `#{target.make_red}'!"
      end

      say "Deployment set to '#{manifest_filename.make_green}'"
      config.set_deployment(manifest_filename)
      config.save
    end
    # rubocop:enable MethodLength

    def show_current
      say(deployment ? "Current deployment is '#{deployment.make_green}'" : 'Deployment not set')
    end

    usage 'micro status'
    desc 'Display micro BOSH deployment status'
    def status
      stemcell_cid = deployer_state(:stemcell_cid)
      stemcell_name = deployer_state(:stemcell_name)
      vm_cid = deployer_state(:vm_cid)
      disk_cid = deployer_state(:disk_cid)
      deployment = config.deployment ? config.deployment.make_green : 'not set'.make_red

      say('Stemcell CID'.ljust(15) + stemcell_cid)
      say('Stemcell name'.ljust(15) + stemcell_name)
      say('VM CID'.ljust(15) + vm_cid)
      say('Disk CID'.ljust(15) + disk_cid)
      say('Micro BOSH CID'.ljust(15) + Bosh::Deployer::Config.uuid)
      say('Deployment'.ljust(15) + deployment)

      update_target

      target_name = target ? target.make_green : 'not set'.make_red
      say('Target'.ljust(15) + target_name)
    end

    # rubocop:disable MethodLength
    usage 'micro deploy'
    desc 'Deploy a micro BOSH instance to the currently selected deployment'
    option '--update', 'update existing instance'
    option '--update-if-exists', 'create new or update existing instance'
    def perform(stemcell = nil)
      update = !!options[:update]

      err 'No deployment set' unless deployment

      manifest = load_yaml_file(deployment)

      if stemcell.nil?
        unless manifest.is_a?(Hash)
          err('Invalid manifest format')
        end

        stemcell = dig_hash(manifest, 'resources', 'cloud_properties', 'image_id')

        if stemcell.nil?
          err 'No stemcell provided'
        end
      end

      deployer.check_dependencies

      rel_path = strip_relative_path(deployment)

      desc = "`#{rel_path.make_green}' to `#{target_name.make_green}'"

      if deployer.exists?
        if !options[:update_if_exists] && !update
          err 'Instance exists. Did you mean to --update?'
        end
        confirmation = 'Updating'
        method = :update_deployment
      else
        prefered_dir = File.dirname(File.dirname(deployment))

        unless prefered_dir == Dir.pwd
          confirm_deployment(
            "\n#{'No `bosh-deployments.yml` file found in current directory.'.make_red}\n\n" +
            'Conventionally, `bosh-deployments.yml` should be saved in ' +
            "#{prefered_dir.make_green}.\n" +
            "Is #{Dir.pwd.make_yellow} a directory where you can save state?"
          )
        end

        err 'No existing instance to update' if update
        confirmation = 'Deploying new micro BOSH instance'
        method = :create_deployment

        # make sure the user knows a persistent disk is required
        unless dig_hash(manifest, 'resources', 'persistent_disk')
          quit("No persistent disk configured in #{MICRO_BOSH_YAML}".make_red)
        end
      end

      confirm_deployment("#{confirmation} #{desc}")

      if File.extname(stemcell) == '.tgz'
        stemcell_file = Bosh::Cli::Stemcell.new(stemcell)

        say("\nVerifying stemcell...")
        stemcell_file.validate
        say("\n")

        unless stemcell_file.valid?
          err('Stemcell is invalid, please fix, verify and upload again')
        end

        stemcell_archive = Bosh::Stemcell::Archive.new(stemcell)
      end

      renderer = Bosh::Deployer::DeployerRenderer.new
      renderer.start
      deployer.renderer = renderer

      start_time = Time.now

      deployer.send(method, stemcell, stemcell_archive)

      renderer.finish('done')

      duration = renderer.duration || (Time.now - start_time)

      update_target

      say("Deployed #{desc}, took #{format_time(duration).make_green} to complete")
    end
    # rubocop:enable MethodLength

    usage 'micro delete'
    desc 'Delete micro BOSH instance (including persistent disk)'
    def delete
      unless deployer.exists?
        err 'No existing instance to delete'
      end

      name = deployer.state.name

      say(
        "\nYou are going to delete micro BOSH deployment `#{name}'.\n\n" +
        "THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red
      )

      unless confirmed?
        say 'Canceled deleting deployment'.make_green
        return
      end

      renderer = Bosh::Deployer::DeployerRenderer.new
      renderer.start
      deployer.renderer = renderer

      start_time = Time.now

      deployer.delete_deployment

      renderer.finish('done')

      duration = renderer.duration || (Time.now - start_time)

      say("Deleted deployment '#{name}', took #{format_time(duration).make_green} to complete")
    end

    usage 'micro deployments'
    desc 'Show the list of deployments'
    def list
      file = File.join(work_dir, Bosh::Deployer::InstanceManager::DEPLOYMENTS_FILE)
      if File.exists?(file)
        deployments = load_yaml_file(file)['instances']
      else
        deployments = []
      end

      err('No deployments') if deployments.size == 0

      na = 'n/a'

      deployments_table = table do |t|
        t.headings = ['Name', 'VM name', 'Stemcell name']
        deployments.each do |r|
          t << [r[:name], r[:vm_cid] || na, r[:stemcell_cid] || na]
        end
      end

      say("\n")
      say(deployments_table)
      say("\n")
      say("Deployments total: #{deployments.size}")
    end

    usage 'micro agent <args>'
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

    usage 'micro apply'
    desc 'Apply spec'
    def apply(spec)
      deployer.apply(Bosh::Deployer::Specification.new(load_yaml_file(spec)))
    end

    private

    def deployer(manifest_filename = nil)
      deployment_required unless manifest_filename

      if @deployer.nil?
        manifest_filename ||= deployment

        unless File.exists?(manifest_filename)
          err("Cannot find deployment manifest in `#{manifest_filename}'")
        end

        manifest = load_yaml_file(manifest_filename)

        manifest['dir'] ||= work_dir
        manifest['logging'] ||= {}
        unless manifest['logging']['file']
          log_file = File.join(File.dirname(manifest_filename),
                               'bosh_micro_deploy.log')
          manifest['logging']['file'] = log_file
        end

        @deployer = Bosh::Deployer::InstanceManager.create(manifest)
      end

      @deployer
    end

    def find_deployment(name)
      if File.directory?(name)
        filename = File.join("#{name}", MICRO_BOSH_YAML)
      else
        filename = name
      end

      File.expand_path(filename, Dir.pwd)
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

    # rubocop:disable MethodLength
    def update_target
      if deployer.exists?
        bosh_ip = deployer.discover_bosh_ip
        if URI.parse(target).host != bosh_ip
          set_current(deployment)
        end

        director = Bosh::Cli::Client::Director.new(target)

        if options[:director_checks]
          begin
            status = director.get_status
          rescue Bosh::Cli::AuthError
            status = {}
          rescue Bosh::Cli::DirectorError
            err("Cannot talk to director at '#{target}', please set correct target")
          end
        else
          status = { 'name' => 'Unknown Director', 'version' => 'n/a' }
        end
      else
        status = {}
      end

      config.target_name = status['name']
      config.target_version = status['version']
      config.target_uuid = status['uuid']

      config.save
    end
    # rubocop:enable MethodLength

    def confirm_deployment(msg)
      unless confirmed?(msg)
        cancel_deployment
      end
    end

    def deployer_state(column)
      value = deployer.state.send(column)

      if value
        value.make_green
      else
        'n/a'.make_red
      end
    end

    def strip_relative_path(path)
      path[/#{Regexp.escape File.join(Dir.pwd, '')}(.*)/, 1] || path
    end

    def dig_hash(hash, *path)
      path.inject(hash) do |location, key|
        location.respond_to?(:keys) ? location[key] : nil
      end
    end
  end
end
