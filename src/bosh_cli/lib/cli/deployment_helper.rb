module Bosh::Cli
  module DeploymentHelper
    def build_manifest
      deployment_required
      return @manifest if @manifest
      @manifest = Manifest.new(deployment, director)
      @manifest.load
      @manifest
    end

    def prepare_deployment_manifest(options = {})
      manifest = build_manifest
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
      manifest.resolve_release_aliases
      manifest.resolve_stemcell_aliases

      show_empty_changeset = options.fetch(:show_empty_changeset, true)
      redact_diff = options.fetch(:redact_diff, false)

      manifest_hash = manifest.hash.dup
      current_deployment = director.get_deployment(manifest_hash['name'])

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
      diff.add_hash(normalize_deployment_manifest(manifest_hash), :new)
      diff.add_hash(normalize_deployment_manifest(current_manifest), :old)
      @_diff_key_visited = { 'name' => 1, 'director_uuid' => 1 }

      header('Detecting deployment changes')

      if !diff.changed? && !show_empty_changeset
        return false
      end

      if diff[:release]
        print_summary(diff, :release, redact_diff)
        nl
      end

      if diff[:releases]
        print_summary(diff, :releases, redact_diff)
        nl
      end

      print_summary(diff, :compilation, redact_diff)
      nl

      print_summary(diff, :update, redact_diff)
      nl

      print_summary(diff, :resource_pools, redact_diff)
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

    def job_unique_in_deployment?(manifest_hash, job_name)
      job = find_job(manifest_hash, job_name)
      job ? job.fetch('instances') == 1 : false
    end

    def job_exists_in_deployment?(manifest_hash, job_name)
      !!find_job(manifest_hash, job_name)
    end

    def prompt_for_job_and_index
      manifest = prepare_deployment_manifest
      deployment_name = manifest.name
      instances = director.fetch_vm_state(deployment_name, {}, false)
      return [instances.first['job'], instances.first['index'] ] if instances.size == 1

      choose do |menu|
        menu.prompt = 'Choose an instance: '
        instances.each do |instance|
          job_name = instance['job']
          index = instance['index']
          id = instance['id']
          name = "#{job_name}/#{index}"
          name = "#{name} (#{id})" if id
          menu.choice(name) { [job_name, index] }
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
  end
end
