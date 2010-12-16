module Bosh::Cli::Command
  class Deployment < Base

    def show_current
      say(deployment ? "Current deployment is '#{deployment}'" : "Deployment not set")
    end

    def set_current(name)
      manifest_filename = File.expand_path(work_dir + "/deployments/#{name}.yml")
      manifest          = read_manifest(manifest_filename)
      new_target        = manifest["target"]

      if !new_target
        err("Deployment manifest '#{name}' has no target, please add it before proceeding")
      end

      if target != new_target
        config.target = new_target
        say("WARNING! Your target has been changed to '#{new_target}'")
      end

      say("Deployment set to '#{name}'")
      config.deployment = name
      config.save
    end
    
    def perform
      err("Please log in first") unless logged_in?
      err("Please choose deployment first") unless deployment

      manifest_filename = File.expand_path(work_dir + "/deployments/#{deployment}.yml")
      manifest = read_manifest(manifest_filename)

      if manifest["name"].blank? || manifest["release"].blank? || manifest["target"].blank?
        err("Invalid manifest for '#{deployment}': name, release and target are all required")
      end

      desc = "to '#{target}' using '#{deployment}' deployment manifest"
      
      say("Deploying #{desc}...")
      say("\n")

      status, body = director.deploy(manifest_filename)

      responses = {
        :done          => "Deployed #{desc}",
        :non_trackable => "Started deployment but director at '#{target}' doesn't support deployment tracking",
        :track_timeout => "Started deployment but timed out out while tracking status",
        :error         => "Started deployment but received an error while tracking status",
        :invalid       => "Deployment is invalid, please fix it and deploy again"
      }

      say responses[status] || "Cannot deploy: #{body}"      
    end

    private

    def read_manifest(filename)
      if !File.exists?(filename)
        err("Missing manifest for #{name}")
      end

      YAML.load_file(filename)
    end
    
  end
end

