module Bosh::Cli::Command
  class Deployment < Base
    include Bosh::Cli::DeploymentHelper

    def show_current
      say(deployment ? "Current deployment is '#{deployment}'" : "Deployment not set")
    end

    def set_current(name)
      manifest_filename = find_deployment(name)

      if !File.exists?(manifest_filename)
        err("Missing manifest for #{name} (tried '#{manifest_filename}')")
      end

      manifest = load_yaml_file(manifest_filename)

      unless manifest.is_a?(Hash) && manifest.has_key?("target")
        err("Deployment '#{name}' has no target defined")
      end

      new_target = normalize_url(manifest["target"])

      if !new_target
        err("Deployment manifest '#{name}' has no target, please add it before proceeding")
      end

      if target != new_target
        config.target = new_target
        status = director.get_status rescue { } # generic rescue justified as we force target

        config.target_name = status["name"]
        config.target_version = status["version"]

        say("WARNING! Your target has been changed to '#{full_target_name}'")
      end

      say("Deployment set to '#{manifest_filename}'")
      config.deployment = manifest_filename
      config.save
    end

    def perform(*options)
      auth_required
      recreate = options.include?("--recreate")

      new_manifest = prepare_deployment_manifest

      desc = "to #{target_name.green} using '#{deployment.green}' deployment manifest"
      say "You are about to start the deployment #{desc}"

      inspect_deployment_changes(new_manifest) if interactive?

      say "Deploying #{desc}..."
      nl

      if interactive? && ask("Please review all changes above and type 'yes' if you are ready to deploy: ") != "yes"
        cancel_deployment
      end

      status, body = director.deploy(deployment, :recreate => recreate)

      responses = {
        :done          => "Deployed #{desc}",
        :non_trackable => "Started deployment but director at '#{target}' doesn't support deployment tracking",
        :track_timeout => "Started deployment but timed out out while tracking status",
        :error         => "Started deployment but received an error while tracking status",
        :invalid       => "Deployment is invalid, please fix it and deploy again"
      }

      say responses[status] || "Cannot deploy: #{body}"
    end

    def delete(name)
      auth_required

      say "\nYou are going to delete deployment `#{name}'.\n\nTHIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red

      unless operation_confirmed?
        say "Canceled deleting deployment".green
        return
      end

      status, message = director.delete_deployment(name)

      responses = {
        :done          => "Deleted deployment '%s'" % [ name ],
        :non_trackable => "Deployment delete in progress but director at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking deployment deletion progress",
        :error         => "Attempted to delete deployment but received an error while tracking status",
      }

      say responses[status] || "Cannot delete deployment: #{message}"
    end

    def list
      auth_required

      deployments = director.list_deployments

      err("No deployments") if deployments.size == 0

      deployments_table = table do |t|
        t.headings = [ "Name" ]
        deployments.each do |r|
          t << [ r["name"]  ]
        end
      end

      say("\n")
      say(deployments_table)
      say("\n")
      say("Deployments total: %d" % deployments.size)
    end
  end
end

