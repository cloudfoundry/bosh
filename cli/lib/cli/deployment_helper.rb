# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module DeploymentHelper

    def prepare_deployment_manifest(options = {})
      # TODO: extract to helper class
      deployment_required
      manifest_filename = deployment

      unless File.exists?(manifest_filename)
        err("Cannot find deployment manifest in `#{manifest_filename}'")
      end

      manifest = load_yaml_file(manifest_filename)
      manifest_yaml = File.read(manifest_filename)

      if manifest["name"].blank?
        err("Deployment name not found in the deployment manifest")
      end

      if manifest["target"]
        err(manifest_target_upgrade_notice)
      end

      if options[:resolve_properties]
        compiler = DeploymentManifestCompiler.new(manifest_yaml)
        properties = {}

        begin
          say("Getting deployment properties from director...")
          properties = director.list_properties(manifest["name"])
        rescue Bosh::Cli::DirectorError
          say("Unable to get properties list from director, " +
                  "trying without it...")
        end

        say("Compiling deployment manifest...")
        compiler.properties = properties.inject({}) do |hash, property|
          hash[property["name"]] = property["value"]
          hash
        end

        manifest_yaml = compiler.result
        manifest = YAML.load(manifest_yaml)
      end

      if manifest["name"].blank? || manifest["director_uuid"].blank?
        err("Invalid manifest `#{File.basename(deployment)}': " +
              "name and director UUID are required")
      end

      if manifest["release"].blank? && manifest["releases"].blank?
        err("Deployment manifest doesn't have release information: '" +
              "please add 'release' or 'releases' section")
      end

      options[:yaml] ? manifest_yaml : manifest
    end

    # Check if the 2 deployments are different.
    # Print out a summary if "show" is true.
    def deployment_changed?(current_manifest, manifest, show=true)
      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      changed = diff.changed?

      if changed && show
        @_diff_key_visited = { }
        diff.keys.each do |key|
          unless @_diff_key_visited[key]
            print_summary(diff, key)
            nl
          end
        end
      end

      changed
    end

    # Interactive walkthrough of deployment changes,
    # expected to bail out of CLI using 'cancel_deployment'
    # if something goes wrong, so it doesn't need to have
    # a meaningful return value.
    # @return Boolean Were there any changes in deployment manifest?
    def inspect_deployment_changes(manifest, options = { })
      show_empty_changeset = true

      if options.has_key?(:show_empty_changeset)
        show_empty_changeset = options[:show_empty_changeset]
      end

      manifest = manifest.dup
      current_deployment = director.get_deployment(manifest["name"])

      # We cannot retrieve current manifest until there was at least one
      # successful deployment. There used to be a warning about that
      # but it turned out to be confusing to many users and thus has
      # been removed.
      return if current_deployment["manifest"].nil?
      current_manifest = YAML.load(current_deployment["manifest"])

      unless current_manifest.is_a?(Hash)
        err("Current deployment manifest format is invalid, " +
                "check if director works properly")
      end

      # TODO: validate new deployment manifest
      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      @_diff_key_visited = { "name" => 1, "director_uuid" => 1 }

      say("Detecting changes in deployment...".green)
      nl

      if !diff.changed? && !show_empty_changeset
        return false
      end

      if diff[:release]
        print_summary(diff, :release)
        warn_about_release_changes(diff[:release])
        nl
      end

      if diff[:releases]
        print_summary(diff, :releases)
        diff[:releases].each do |release_diff|
          warn_about_release_changes(release_diff)
        end
        nl
      end

      print_summary(diff, :compilation)
      nl

      print_summary(diff, :update)
      nl

      print_summary(diff, :resource_pools)

      old_stemcells = Set.new
      new_stemcells = Set.new

      diff[:resource_pools].each do |pool|
        old_stemcells << {
          :name => pool[:stemcell][:name].old,
          :version => pool[:stemcell][:version].old
        }
        new_stemcells << {
          :name => pool[:stemcell][:name].new,
          :version => pool[:stemcell][:version].new
        }
      end

      if old_stemcells != new_stemcells
        unless confirmed?("Stemcell update has been detected. " +
                          "Are you sure you want to update stemcells?")
          cancel_deployment
        end
      end

      if old_stemcells.size != new_stemcells.size
        say("Stemcell update seems to be inconsistent with current " +
            "deployment. Please carefully review changes above.".red)
        unless confirmed?("Are you sure this configuration is correct?")
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
      say("Cannot get current deployment information from director, " +
          "possibly a new deployment".red)
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
      quit("Deployment canceled".red)
    end

    def manifest_error(err)
      err("Deployment manifest error: #{err}")
    end

    def manifest_target_upgrade_notice
      <<-EOS.gsub(/^\s*/, "").gsub(/\n$/, "")
        Please upgrade your deployment manifest to use director UUID instead
        of target. Just replace 'target' key with 'director_uuid' key in your
        manifest. You can get your director UUID by targeting your director
        with 'bosh target' and running 'bosh status' command afterwards.
      EOS
    end

    def print_summary(diff, key, title = nil)
      title ||= key.to_s.gsub(/[-_]/, " ").capitalize

      say(title.green)
      summary = diff[key].summary
      if summary.empty?
        say("No changes")
      else
        say(summary.join("\n"))
      end
      @_diff_key_visited[key.to_s] = 1
    end

    def normalize_deployment_manifest(manifest)
      normalized = manifest.dup

      %w(releases networks jobs resource_pools).each do |section|
        normalized[section] ||= []

        unless normalized[section].kind_of?(Array)
          manifest_error("#{section} is expected to be an array")
        end

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
        # VIP and dynamic networks do not require subnet,
        # but if it's there we can run some sanity checks
        next unless network.has_key?("subnets")

        unless network["subnets"].kind_of?(Array)
          manifest_error("network subnets is expected to be an array")
        end

        subnets = network["subnets"].inject({}) do |acc, e|
          if e["range"].blank?
            manifest_error("missing range for one of subnets " +
                               "in '#{network_name}'")
          end
          if acc.has_key?(e["range"])
            manifest_error("duplicate network range '#{e['range']}' " +
                               "in '#{network}'")
          end
          acc[e["range"]] = e
          acc
        end

        normalized["networks"][network_name]["subnets"] = subnets
      end

      normalized
    end

    def warn_about_release_changes(release_diff)
      if release_diff[:name].changed?
        say("Release name has changed: %s -> %s".red % [
          release_diff[:name].old, release_diff[:name].new])
        unless confirmed?("This is very serious and potentially destructive " +
                            "change. ARE YOU SURE YOU WANT TO DO IT?")
          cancel_deployment
        end
      elsif release_diff[:version].changed?
        say("Release version has changed: %s -> %s".yellow % [
          release_diff[:version].old, release_diff[:version].new])
        unless confirmed?("Are you sure you want to deploy this version?")
          cancel_deployment
        end
      end
    end

  end
end
