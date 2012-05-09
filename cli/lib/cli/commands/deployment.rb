# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Deployment < Base
    include Bosh::Cli::DeploymentHelper

    def show_current
      say(deployment ?
              "Current deployment is '#{deployment.green}'" :
              "Deployment not set")
    end

    def set_current(name)
      manifest_filename = find_deployment(name)

      unless File.exists?(manifest_filename)
        err("Missing manifest for #{name} (tried '#{manifest_filename}')")
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

      say("Deployment set to '#{manifest_filename.green}'")
      config.set_deployment(manifest_filename)
      config.save
    end

    def perform(*options)
      auth_required
      recreate = options.include?("--recreate")

      manifest_yaml = prepare_deployment_manifest(:yaml => true,
                                                  :resolve_properties => true)

      if interactive?
        inspect_deployment_changes(YAML.load(manifest_yaml))
        say("Please review all changes carefully".yellow)
      end

      desc = "`#{File.basename(deployment).green}' to `#{target_name.green}'"

      unless confirmed?("Deploying #{desc}")
        cancel_deployment
      end

      status, body = director.deploy(manifest_yaml, :recreate => recreate)

      responses = {
        :done => "Deployed #{desc}",
        :non_trackable => "Started deployment but director at `#{target}' " +
                           "doesn't support deployment tracking",
        :track_timeout => "Started deployment but timed out out " +
                          "while tracking status",
        :error => "Started deployment but received an error " +
                  "while tracking status",
        :invalid => "Deployment is invalid, please fix it and deploy again"
      }

      say(responses[status] || "Cannot deploy: #{body}")
    end

    def delete(name, *options)
      auth_required
      force = options.include?("--force")

      say("\nYou are going to delete deployment `#{name}'.\n\n")
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)

      unless confirmed?
        say("Canceled deleting deployment".green)
        return
      end

      status, message = director.delete_deployment(name, :force => force)

      responses = {
        :done          => "Deleted deployment '#{name}'",
        :non_trackable => "Deployment delete in progress but director " +
            "at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking deployment " +
            "deletion progress",
        :error         => "Attempted to delete deployment but received " +
            "an error while tracking status",
      }

      say(responses[status] || "Cannot delete deployment: #{message}")
    end

    def list
      auth_required

      deployments = director.list_deployments

      err("No deployments") if deployments.size == 0

      deployments_table = table do |t|
        t.headings = ["Name"]
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
