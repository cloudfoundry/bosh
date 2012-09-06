# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Deployment < Base
    include Bosh::Cli::DeploymentHelper

    # usage "deployment [<name>]"
    # desc  "Choose deployment to work with " +
    #           "(it also updates current target)"
    # route do |args|
    #   if args.size > 0
    #     [:deployment, :set_current]
    #   else
    #     [:deployment, :show_current]
    #   end
    # end
    def show_current
      say(deployment ?
            "Current deployment is `#{deployment.green}'" :
            "Deployment not set".red)
    end

    # usage "deployment [<name>]"
    # desc  "Choose deployment to work with " +
    #           "(it also updates current target)"
    # route do |args|
    #   if args.size > 0
    #     [:deployment, :set_current]
    #   else
    #     [:deployment, :show_current]
    #   end
    # end
    def set_current(name)
      manifest_filename = find_deployment(name)

      unless File.exists?(manifest_filename)
        err("Missing manifest for #{name} (tried `#{manifest_filename}')")
      end

      manifest = load_yaml_file(manifest_filename)

      unless manifest.is_a?(Hash)
        err("Invalid manifest format")
      end

      unless manifest["target"].blank?
        err(manifest_target_upgrade_notice)
      end

      if manifest["director_uuid"].blank?
        err("Director UUID is not defined in deployment manifest")
      end

      if target
        old_director = Bosh::Cli::Director.new(target, username, password)
        old_director_uuid = old_director.get_status["uuid"] rescue nil
      else
        old_director_uuid = nil
      end

      new_director_uuid = manifest["director_uuid"]

      if old_director_uuid != new_director_uuid
        new_target_url = config.resolve_alias(:target, new_director_uuid)

        if new_target_url.blank?
          err("This manifest references director with UUID " +
                "#{new_director_uuid}.\n" +
                "You've never targeted it before.\n" +
                "Please find your director IP or hostname and target it first.")
        end

        new_director = Bosh::Cli::Director.new(new_target_url,
                                               username, password)
        status = new_director.get_status

        config.target = new_target_url
        config.target_name = status["name"]
        config.target_version = status["version"]
        config.target_uuid = status["uuid"]
        say("#{"WARNING!".red} Your target has been " +
            "changed to `#{target.red}'!")
      end

      say("Deployment set to `#{manifest_filename.green}'")
      config.set_deployment(manifest_filename)
      config.save
    end

    # usage  "edit deployment"
    # desc   "Edit current deployment manifest"
    # route  :deployment, :edit
    def edit
      unless deployment
        quit("Deployment not set".red)
      end

      editor = ENV['EDITOR'] || "vi"
      system("#{editor} #{deployment}")
    end

    # usage  "deploy"
    # desc   "Deploy according to the currently selected " +
    #            "deployment manifest"
    # option "--recreate", "recreate all VMs in deployment"
    # route  :deployment, :perform
    def perform(*options)
      auth_required
      recreate = options.include?("--recreate")

      manifest_yaml =
        prepare_deployment_manifest(:yaml => true, :resolve_properties => true)

      if interactive?
        inspect_deployment_changes(YAML.load(manifest_yaml))
        say("Please review all changes carefully".yellow)
      end

      desc = "`#{File.basename(deployment).green}' to `#{target_name.green}'"

      unless confirmed?("Deploying #{desc}")
        cancel_deployment
      end

      status, _ = director.deploy(manifest_yaml, :recreate => recreate)

      task_report(status, "Deployed #{desc}")
    end

    # usage "delete deployment <name>"
    # desc  "Delete deployment"
    # option "--force", "ignore all errors while deleting parts " +
    #     "of the deployment"
    # route :deployment, :delete
    def delete(name, *options)
      auth_required
      force = options.include?("--force")

      say("\nYou are going to delete deployment `#{name}'.\n\n")
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)

      unless confirmed?
        say("Canceled deleting deployment".green)
        return
      end

      status, _ = director.delete_deployment(name, :force => force)

      task_report(status, "Deleted deployment `#{name}'")
    end

    # usage "validate jobs"
    # desc  "Validates all jobs in the current release using current" +
    #       "deployment manifest as the source of properties"
    # route :deployment, :validate_jobs
    def validate_jobs
      check_if_release_dir
      manifest = prepare_deployment_manifest(:resolve_properties => true)

      nl
      say("Analyzing release directory...".yellow)

      say(" - discovering packages")
      packages = Bosh::Cli::PackageBuilder.discover(
        work_dir,
        :dry_run => true,
        :final => false
      )

      say(" - discovering jobs")
      jobs = Bosh::Cli::JobBuilder.discover(
        work_dir,
        :dry_run => true,
        :final => false,
        :package_names => packages.map {|package| package.name}
      )

      say(" - validating properties")
      validator = Bosh::Cli::JobPropertyValidator.new(jobs, manifest)
      validator.validate

      unless validator.jobs_without_properties.empty?
        nl
        say("Legacy jobs (no properties defined): ".yellow)
        validator.jobs_without_properties.sort { |a, b|
          a.name <=> b.name
        }.each do |job|
          say(" - #{job.name}")
        end
      end

      if validator.template_errors.empty?
        nl
        say("No template errors found".green)
      else
        nl
        say("Template errors: ".yellow)
        validator.template_errors.each do |error|
          nl
          path = Pathname.new(error.template_path)
          rel_path = path.relative_path_from(Pathname.new(release.dir))

          say(" - #{rel_path}:")
          say("     line #{error.line}:".yellow + " #{error.exception.to_s}")
        end
      end
    end

    # usage "deployments"
    # desc  "Show the list of available deployments"
    # route :deployment, :list
    def list
      auth_required

      deployments = director.list_deployments

      err("No deployments") if deployments.size == 0

      deployments_table = table do |t|
        t.headings = %w(Name)
        deployments.each do |r|
          t << [r["name"]]
        end
      end

      say("\n")
      say(deployments_table)
      say("\n")
      say("Deployments total: %d" % deployments.size)
    end
  end
end
