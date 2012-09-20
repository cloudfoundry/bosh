# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Deployment < Base
    include Bosh::Cli::DeploymentHelper

    # bosh deployment
    usage "deployment"
    desc "Get/set current deployment"
    def set_current(filename = nil)
      if filename.nil?
        show_current
        return
      end

      manifest_filename = find_deployment(filename)

      unless File.exists?(manifest_filename)
        err("Missing manifest for `#{filename}'")
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

        new_director = Bosh::Cli::Director.new(
          new_target_url, username, password)

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

    # bosh edit deployment
    usage "edit deployment"
    desc "Edit current deployment manifest"
    def edit
      deployment_required
      editor = ENV['EDITOR'] || "vi"
      system("#{editor} #{deployment}")
    end

    # bosh deploy
    usage "deploy"
    desc "Deploy according to the currently selected deployment manifest"
    option "--recreate", "recreate all VMs in deployment"
    def perform
      auth_required
      recreate = !!options[:recreate]

      manifest_yaml = prepare_deployment_manifest(
        :yaml => true, :resolve_properties => true)

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

    # bosh delete deployment
    usage "delete deployment"
    desc "Delete deployment"
    option "--force", "ignore errors while deleting"
    def delete(name)
      auth_required
      force = !!options[:force]

      say("\nYou are going to delete deployment `#{name}'.".red)
      nl
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)

      unless confirmed?
        say("Canceled deleting deployment".green)
        return
      end

      status, _ = director.delete_deployment(name, :force => force)

      task_report(status, "Deleted deployment `#{name}'")
    end

    # bosh validate jobs
    usage "validate jobs"
    desc "Validates all jobs in the current release using current " +
         "deployment manifest as the source of properties"
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

    # bosh deployments
    usage "deployments"
    desc "Show the list of available deployments"
    def list
      auth_required
      deployments = director.list_deployments

      err("No deployments") if deployments.empty?

      deployments_table = table do |t|
        t.headings = %w(Name)
        deployments.each do |r|
          t << [r["name"]]
        end
      end

      nl
      say(deployments_table)
      nl
      say("Deployments total: %d" % deployments.size)
    end

    # bosh download manifest
    usage "download manifest"
    desc "Download deployment manifest locally"
    def download_manifest(deployment_name, save_as = nil)
      auth_required

      if save_as && File.exists?(save_as) &&
         !confirmed?("Overwrite `#{save_as}'?")
        err("Please choose another file to save the manifest to")
      end

      deployment = director.get_deployment(deployment_name)

      if save_as
        File.open(save_as, "w") do |f|
          f.write(deployment["manifest"])
        end
        say("Deployment manifest saved to `#{save_as}'".green)
      else
        say(deployment["manifest"])
      end
    end

    private

    def show_current
      if deployment
        if interactive?
          say("Current deployment is `#{deployment.green}'")
        else
          say(deployment)
        end
      else
        err("Deployment not set")
      end
    end

  end
end
