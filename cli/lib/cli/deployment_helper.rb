module Bosh::Cli
  module DeploymentHelper

    def prepare_deployment_manifest(options = {})
      # TODO: extract to helper class
      err("Please choose deployment first") unless deployment
      manifest_filename = deployment

      if !File.exists?(manifest_filename)
        err("Cannot find deployment manifest in `#{manifest_filename}'")
      end

      manifest = load_yaml_file(manifest_filename)
      manifest_yaml = File.read(manifest_filename)

      if manifest["name"].blank?
        err("Deployment name not found in the deployment manifest")
      end

      if manifest["target"]
        err manifest_target_upgrade_notice
      end

      if options[:resolve_properties]
        compiler = DeploymentManifestCompiler.new(manifest_yaml)
        properties = {}

        begin
          say "Getting deployment properties from director..."
          properties = director.list_properties(manifest["name"])
        rescue Bosh::Cli::DirectorError
          say "Unable to get properties list from director, trying without it..."
        end

        say "Compiling deployment manifest..."
        compiler.properties = properties.inject({}) do |h, property|
          h[property["name"]] = property["value"]; h
        end

        manifest_yaml = compiler.result
        manifest = YAML.load(manifest_yaml)
      end

      if manifest["name"].blank? || manifest["release"].blank? || manifest["director_uuid"].blank?
        err("Invalid manifest `#{File.basename(deployment)}': name, release and director UUID are all required")
      end

      options[:yaml] ? manifest_yaml : manifest
    end

    # Interactive walkthrough of deployment changes, expected to bail out of CLI using 'cancel_deployment'
    # if something goes wrong, so it doesn't need to have a meaningful return value.
    # @return Boolean Were there any changes in deployment manifest?
    def inspect_deployment_changes(manifest, options = { })
      show_empty_changeset = options.has_key?(:show_empty_changeset) ? !!options[:show_empty_changeset] : true

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
      @_diff_key_visited = { "name" => 1, "director_uuid" => 1 }

      say "Detecting changes in deployment...".green
      nl

      if !diff.changed? && !show_empty_changeset
        return false
      end

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
        unless @_diff_key_visited[key]
          print_summary(diff, key)
          nl
        end
      end

      diff.changed?
    rescue Bosh::Cli::DeploymentNotFound
      say "Cannot get current deployment information from director, possibly a new deployment".red
      true
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

    def manifest_target_upgrade_notice
      <<-EOS.gsub(/^\s*/, "").gsub(/\n$/, "")
        Please upgrade your deployment manifest to use director UUID instead of target
        Just replace 'target' key with 'director_uuid' key in your manifest.
        You can get your director UUID by targeting your director with 'bosh target'
        and running 'bosh status' command afterwards.
      EOS
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
      @_diff_key_visited[key.to_s] = 1
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
