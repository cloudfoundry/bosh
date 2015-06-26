module Bosh::Cli
  module DeploymentHelper
    def prepare_deployment_manifest(options = {})
      deployment_required
      manifest = Manifest.new(deployment, director)
      manifest.load
      if options.fetch(:show_state, false)
        show_current_state(manifest.name)
      end
      manifest.validate(options)

      manifest
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
            print_summary(diff, key, false)
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
      show_empty_changeset = options.fetch(:show_empty_changeset, true)
      interactive = options.fetch(:interactive, false)
      redact_diff = options.fetch(:redact_diff, false)

      manifest = manifest.dup
      current_deployment = director.get_deployment(manifest['name'])

      # We cannot retrieve current manifest until there was at least one
      # successful deployment. There used to be a warning about that
      # but it turned out to be confusing to many users and thus has
      # been removed.
      return if current_deployment['manifest'].nil?
      current_manifest = Psych.load(current_deployment['manifest'])

      unless current_manifest.is_a?(Hash)
        err('Current deployment manifest format is invalid, check if director works properly')
      end

      diff = Bosh::Cli::HashChangeset.new
      diff.add_hash(normalize_deployment_manifest(manifest), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      @_diff_key_visited = { 'name' => 1, 'director_uuid' => 1 }

      header('Detecting deployment changes')

      if !diff.changed? && !show_empty_changeset
        return false
      end

      if diff[:release]
        print_summary(diff, :release, redact_diff)
        warn_about_release_changes(diff[:release]) if interactive
        nl
      end

      if diff[:releases]
        print_summary(diff, :releases, redact_diff)
        if interactive
          diff[:releases].each do |release_diff|
            warn_about_release_changes(release_diff)
          end
        end
        nl
      end

      print_summary(diff, :compilation, redact_diff)
      nl

      print_summary(diff, :update, redact_diff)
      nl

      print_summary(diff, :resource_pools, redact_diff)
      warn_about_stemcell_changes(diff) if interactive
      nl

      print_summary(diff, :disk_pools, redact_diff)
      nl

      print_summary(diff, :networks, redact_diff)
      nl

      print_summary(diff, :jobs, redact_diff)
      nl

      print_summary(diff, :properties, redact_diff)
      nl

      diff.keys.each do |key|
        unless @_diff_key_visited[key]
          print_summary(diff, key, redact_diff)
          nl
        end
      end

      diff.changed?
    rescue Bosh::Cli::ResourceNotFound
      say('Cannot get current deployment information from director, possibly a new deployment'.make_red)
      true
    end

    def warn_about_stemcell_changes(diff)
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
        unless confirmed?('Stemcell update has been detected. Are you sure you want to update stemcells?')
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
    end

    def job_unique_in_deployment?(manifest_hash, job_name)
      job = find_job(manifest_hash, job_name)
      job ? job.fetch('instances') == 1 : false
    end

    def job_exists_in_deployment?(manifest_hash, job_name)
      !!find_job(manifest_hash, job_name)
    end

    def job_must_exist_in_deployment(manifest_hash, job)
      err("Job `#{job}' doesn't exist") unless job_exists_in_deployment?(manifest_hash, job)
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

    # return a job/errand selected by user by name
    def prompt_for_errand_name
      errands = list_errands

      err('Deployment has no available errands') if errands.size == 0

      choose do |menu|
        menu.prompt = 'Choose an errand: '
        errands.each do |errand, index|
          menu.choice("#{errand['name']}") { errand }
        end
      end
    end

    def jobs_and_indexes
      jobs = prepare_deployment_manifest.hash.fetch('jobs')

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

    def find_job(manifest_hash, job_name)
      jobs = manifest_hash.fetch('jobs')
      jobs.find { |job| job.fetch('name') == job_name }
    end

    def list_errands
      deployment_name = prepare_deployment_manifest.name
      director.list_errands(deployment_name)
    end

    def find_deployment(name)
      if File.exists?(name)
        File.expand_path(name)
      else
        File.expand_path(File.join(work_dir, 'deployments', "#{name}.yml"))
      end
    end

    def print_summary(diff, key, redact, title = nil)
      title ||= key.to_s.gsub(/[-_]/, ' ').capitalize

      say(title.make_green)

      summary = diff[key] && diff[key].summary
      if !summary || summary.empty?
        say('No changes')
      else
        if redact
          say("Changes found - Redacted")
        else
          say(summary.join("\n"))
        end
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
  end
end
