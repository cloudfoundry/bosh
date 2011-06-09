module Bosh::Cli::Command
  class Deployment < Base

    def show_current
      say(deployment ? "Current deployment is '#{deployment}'" : "Deployment not set")
    end

    def set_current(name)
      manifest_filename = find_deployment(name)

      if !File.exists?(manifest_filename)
        err("Missing manifest for #{name} (tried '#{manifest_filename}')")
      end

      manifest   = load_yaml_file(manifest_filename)

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
      err("Please choose deployment first") unless deployment

      recreate = false
      if options.include?("--recreate")
        recreate = true
      end

      manifest_filename = deployment

      if !File.exists?(manifest_filename)
        err("Missing deployment at '#{deployment}'")
      end

      new_manifest = load_yaml_file(manifest_filename)

      if new_manifest["name"].blank? || new_manifest["release"].blank? || new_manifest["target"].blank?
        err("Invalid manifest for '#{deployment}': name, release and target are all required")
      end

      desc = "to #{target_name.green} using '#{deployment.green}' deployment manifest"
      say "You are about to start the deployment #{desc}"

      inspect_deployment_changes(new_manifest) if interactive?

      say "Deploying #{desc}..."
      nl

      if interactive? && ask("Please review all changes above and type 'yes' if you are ready to deploy: ") != "yes"
        cancel_deployment
      end

      status, body = director.deploy(manifest_filename, :recreate => recreate)

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

    private

    # Interactive walkthrough of deployment changes, expected to bail out of CLI using 'cancel_deployment'
    # if something goes wrong, so it doesn't need to have a meaningful return value.
    def inspect_deployment_changes(manifest)
      manifest = manifest.dup
      current_deployment = director.get_deployment(manifest["name"])

      if current_deployment["manifest"].nil?
        say "Director currently has an information about this deployment but it's missing the manifest.".red
        say "This is something you probably need to fix before proceeding.".red
        if ask("Please enter 'yes' if you want to ignore this fact and still deploy: ") == 'yes'
          return
        else
          cancel_deployment
        end
      end

      current_manifest = YAML.load(current_deployment["manifest"])

      unless current_manifest.is_a?(Hash)
        err "Current deployment manifest format is invalid, check if director works properly"
      end

      # TODO: validate new deployment manifest
      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      @visited = { "name" => 1, "target" => 1 }

      say "Detecting changes in deployment...".green
      nl
      print_summary(diff, :release)

      if diff[:release][:name].changed?
        say "Release name has changed: %s -> %s".red % [ diff[:release][:name].old, diff[:release][:name].new ]
        if ask("This is very serious and potentially destructive change. ARE YOU SURE YOU WANT TO DO IT? (type 'yes' to confirm): ") != 'yes'
          cancel_deployment
        end
      elsif diff[:release][:version].changed?
        say "Release version has changed: %s -> %s".yellow % [ diff[:release][:version].old, diff[:release][:version].new ]
        if ask("Are you sure you want to deploy this version? (type 'yes' to confirm): ") != 'yes'
          cancel_deployment
        end
      end
      nl

      print_summary(diff, :compilation)
      nl

      print_summary(diff, :update)
      nl

      print_summary(diff, :resource_pools)

      old_stemcells = Set.new
      new_stemcells = Set.new

      diff[:resource_pools].each do |pool|
        old_stemcells << { :name => pool[:stemcell][:name].old, :version => pool[:stemcell][:version].old }
        new_stemcells << { :name => pool[:stemcell][:name].new, :version => pool[:stemcell][:version].new }
      end

      if old_stemcells != new_stemcells
        if ask("Stemcell update has been detected. Are you sure you want to update stemcells? (type 'yes' to confirm): ") != 'yes'
          cancel_deployment
        end
      end

      if old_stemcells.size != new_stemcells.size
        say "Stemcell update seems to be inconsistent with current deployment. Please carefully review changes above.".red
        if ask("Are you sure this configuration is correct? (type 'yes' to confirm): ") != 'yes'
          cancel_deployment
        end
      end

      nl
      print_summary(diff, :networks)
      nl
      print_summary(diff, :jobs)
      nl
      print_summary(diff, :properties)
      nl

      diff.keys.each do |key|
        unless @visited[key]
          print_summary(diff, key)
          nl
        end
      end

    rescue Bosh::Cli::DeploymentNotFound
      say "Cannot get current deployment information from director, possibly a new deployment".red
    end

    private

    def find_deployment(name)
      if File.exists?(name)
        File.expand_path(name)
      else
        File.expand_path(File.join(work_dir, "deployments", "#{name}.yml"))
      end
    end

    def cancel_deployment
      quit "Deployment canceled".red
    end

    def manifest_error(err)
      err("Deployment manifest error: #{err}")
    end

    def print_summary(diff, key, title = nil)
      title ||= key.to_s.gsub(/[-_]/, " ").capitalize

      say title.green
      summary = diff[key].summary
      if summary.empty?
        say "No changes"
      else
        say summary.join("\n")
      end
      @visited[key.to_s] = 1
    end

    def normalize_deployment_manifest(manifest)
      normalized = manifest.dup

      %w(networks jobs resource_pools).each do |section|
        manifest_error("#{section} is expected to be an array") unless normalized[section].kind_of?(Array)
        normalized[section] = normalized[section].inject({}) do |acc, e|
          if e["name"].blank?
            manifest_error("missing name for one of entries in '#{section}'")
          end
          if acc.has_key?(e["name"])
            manifest_error("duplicate entry '#{e['name']}' in '#{section}'")
          end
          acc[e["name"]] = e
          acc
        end
      end

      normalized["networks"].each do |network_name, network|
        manifest_error("network subnets is expected to be an array") unless network["subnets"].kind_of?(Array)
        normalized["networks"][network_name]["subnets"] = network["subnets"].inject({}) do |acc, e|
          if e["range"].blank?
            manifest_error("missing range for one of subnets in '#{network_name}'")
          end
          if acc.has_key?(e["range"])
            manifest_error("duplicate network range '#{e['range']}' in '#{network}'")
          end
          acc[e["range"]] = e
          acc
        end
      end

      normalized
    end

  end
end

