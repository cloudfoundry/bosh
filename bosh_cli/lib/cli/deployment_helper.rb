# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module DeploymentHelper
    include VersionCalc

    def prepare_deployment_manifest(options = {})
      deployment_required
      manifest_filename = deployment

      unless File.exists?(manifest_filename)
        err("Cannot find deployment manifest in `#{manifest_filename}'")
      end

      manifest = load_yaml_file(manifest_filename)
      manifest_yaml = File.read(manifest_filename)

      if manifest['name'].blank?
        err('Deployment name not found in the deployment manifest')
      end

      if manifest['target']
        err(manifest_target_upgrade_notice)
      end

      if options[:resolve_properties]
        compiler = DeploymentManifestCompiler.new(manifest_yaml)
        properties = {}

        begin
          say('Getting deployment properties from director...')
          properties = director.list_properties(manifest['name'])
        rescue Bosh::Cli::DirectorError
          say('Unable to get properties list from director, ' +
                'trying without it...')
        end

        say('Compiling deployment manifest...')
        compiler.properties = properties.inject({}) do |hash, property|
          hash[property['name']] = property['value']
          hash
        end

        manifest = Psych.load(compiler.result)
      end

      if manifest['name'].blank? || manifest['director_uuid'].blank?
        err("Invalid manifest `#{File.basename(deployment)}': " +
              'name and director UUID are required')
      end

      if director.uuid != manifest['director_uuid']
        err("Target director UUID doesn't match UUID from deployment manifest")
      end

      if manifest['release'].blank? && manifest['releases'].blank?
        err("Deployment manifest doesn't have release information: '" +
              "please add 'release' or 'releases' section")
      end

      resolve_release_aliases(manifest)
      resolve_stemcell_aliases(manifest)

      options[:yaml] ? Psych.dump(manifest) : manifest
    end

    # Check if the 2 deployments are different.
    # Print out a summary if "show" is true.
    def deployment_changed?(current_manifest, manifest, show = true)
      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      changed = diff.changed?

      if changed && show
        @_diff_key_visited = {}
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
    def inspect_deployment_changes(manifest, options = {})
      show_empty_changeset = true

      if options.has_key?(:show_empty_changeset)
        show_empty_changeset = options[:show_empty_changeset]
      end

      manifest = manifest.dup
      current_deployment = director.get_deployment(manifest['name'])

      # We cannot retrieve current manifest until there was at least one
      # successful deployment. There used to be a warning about that
      # but it turned out to be confusing to many users and thus has
      # been removed.
      return if current_deployment['manifest'].nil?
      current_manifest = Psych.load(current_deployment['manifest'])

      unless current_manifest.is_a?(Hash)
        err('Current deployment manifest format is invalid, ' +
              'check if director works properly')
      end

      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      @_diff_key_visited = { 'name' => 1, 'director_uuid' => 1 }

      say('Detecting changes in deployment...'.make_green)
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
        unless confirmed?('Stemcell update has been detected. ' +
                            'Are you sure you want to update stemcells?')
          cancel_deployment
        end
      end

      if old_stemcells.size != new_stemcells.size
        say('Stemcell update seems to be inconsistent with current '.make_red +
              'deployment. Please carefully review changes above.'.make_red)
        unless confirmed?('Are you sure this configuration is correct?')
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
    rescue Bosh::Cli::ResourceNotFound
      say('Cannot get current deployment information from director, ' +
            'possibly a new deployment'.make_red)
      true
    end

    def latest_release_versions
      @_latest_release_versions ||= begin
        director.list_releases.inject({}) do |hash, release|
          name = release['name']
          versions = release['versions'] || release['release_versions'].map { |release_version| release_version['version'] }
          latest_version = versions.map { |v| Bosh::Common::VersionNumber.new(v) }.max
          hash[name] = latest_version.to_s
          hash
        end
      end
    end

    # @param [Hash] manifest Deployment manifest (will be modified)
    # @return [void]
    def resolve_release_aliases(manifest)
      releases = manifest['releases'] || [manifest['release']]

      releases.each do |release|
        if release['version'] == 'latest'
          latest_release_version = latest_release_versions[release['name']]
          unless latest_release_version
            err("Release '#{release['name']}' not found on director. Unable to resolve 'latest' alias in manifest.")
          end
          release['version'] = latest_release_version
        end

        if release['version'].to_i.to_s == release['version']
          release['version'] = release['version'].to_i
        end
      end
    end

    def job_unique_in_deployment?(job_name)
      job = find_job(job_name)
      job ? job.fetch('instances') == 1 : false
    end

    def job_exists_in_deployment?(job_name)
      !!find_job(job_name)
    end

    def job_must_exist_in_deployment(job)
      err("Job `#{job}' doesn't exist") unless job_exists_in_deployment?(job)
    end

    def prompt_for_job_and_index
      jobs_list = jobs_and_indexes

      return jobs_list.first if jobs_list.size == 1

      choose do |menu|
        menu.prompt = 'Choose an instance: '
        jobs_list.each do |job_name, index|
          menu.choice("#{job_name}/#{index}") { [job_name, index] }
        end
      end
    end

    def jobs_and_indexes
      jobs = prepare_deployment_manifest.fetch('jobs')

      jobs.inject([]) do |jobs_and_indexes, job|
        job_name = job.fetch('name')
        0.upto(job.fetch('instances').to_i - 1) do |index|
          jobs_and_indexes << [job_name, index]
        end
        jobs_and_indexes
      end
    end

    def cancel_deployment
      quit('Deployment canceled'.make_red)
    end

    private

    def find_job(job_name)
      jobs = prepare_deployment_manifest.fetch('jobs')
      jobs.find { |job| job.fetch('name') == job_name }
    end

    def find_deployment(name)
      if File.exists?(name)
        File.expand_path(name)
      else
        File.expand_path(File.join(work_dir, 'deployments', "#{name}.yml"))
      end
    end

    def manifest_target_upgrade_notice
      <<-EOS.gsub(/^\s*/, '').gsub(/\n$/, '')
        Please upgrade your deployment manifest to use director UUID instead
        of target. Just replace 'target' key with 'director_uuid' key in your
        manifest. You can get your director UUID by targeting your director
        with 'bosh target' and running 'bosh status' command afterwards.
      EOS
    end

    def print_summary(diff, key, title = nil)
      title ||= key.to_s.gsub(/[-_]/, ' ').capitalize

      say(title.make_green)

      summary = diff[key] && diff[key].summary
      if !summary || summary.empty?
        say('No changes')
      else
        say(summary.join("\n"))
      end

      @_diff_key_visited[key.to_s] = 1
    end

    def normalize_deployment_manifest(manifest_hash)
      DeploymentManifest.new(manifest_hash).normalize
    end

    def warn_about_release_changes(release_diff)
      if release_diff[:name].changed?
        say('Release name has changed: %s -> %s'.make_red % [
          release_diff[:name].old, release_diff[:name].new])
        unless confirmed?('This is very serious and potentially destructive ' +
                            'change. ARE YOU SURE YOU WANT TO DO IT?')
          cancel_deployment
        end
      elsif release_diff[:version].changed?
        say('Release version has changed: %s -> %s'.make_yellow % [
          release_diff[:version].old, release_diff[:version].new])
        unless confirmed?('Are you sure you want to deploy this version?')
          cancel_deployment
        end
      end
    end

    # @param [Hash] manifest Deployment manifest (will be modified)
    # @return [void]
    def resolve_stemcell_aliases(manifest)
      return if manifest['resource_pools'].nil?

      manifest['resource_pools'].each do |rp|
        stemcell = rp['stemcell']
        unless stemcell.is_a?(Hash)
          err('Invalid stemcell spec in the deployment manifest')
        end
        if stemcell['version'] == 'latest'
          latest_version = latest_stemcells[stemcell['name']]
          if latest_version.nil?
            err("Latest version for stemcell `#{stemcell['name']}' is unknown")
          end
          # Avoiding {Float,Fixnum} -> String noise in diff
          if latest_version.to_s == latest_version.to_f.to_s
            latest_version = latest_version.to_f
          elsif latest_version.to_s == latest_version.to_i.to_s
            latest_version = latest_version.to_i
          end
          stemcell['version'] = latest_version
        end
      end
    end

    # @return [Array]
    def latest_stemcells
      @_latest_stemcells ||= begin
        stemcells = director.list_stemcells.inject({}) do |hash, stemcell|
          unless stemcell.is_a?(Hash) && stemcell['name'] && stemcell['version']
            err('Invalid director stemcell list format')
          end
          hash[stemcell['name']] ||= []
          hash[stemcell['name']] << stemcell['version']
          hash
        end

        stemcells.inject({}) do |hash, (name, versions)|
          hash[name] = versions.sort { |v1, v2| version_cmp(v2, v1) }.first
          hash
        end
      end
    end
  end
end
