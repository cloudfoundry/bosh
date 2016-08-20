
module Bosh::Cli::Command
  class Deployment < Base
    # bosh deployment
    usage 'deployment'
    desc 'Get/set current deployment'
    def set_current(filename = nil)
      if filename.nil?
        show_current
        return
      end

      manifest_filename = find_deployment(filename)

      unless File.exists?(manifest_filename)
        err("Missing manifest for '#{filename}'")
      end

      manifest = load_yaml_file(manifest_filename)

      unless manifest.is_a?(Hash)
        err('Invalid manifest format')
      end

      unless manifest['target'].blank?
        err(Bosh::Cli::Manifest::MANIFEST_TARGET_UPGRADE_NOTICE)
      end

      if manifest['director_uuid'].blank?
        err('Director UUID is not defined in deployment manifest')
      end

      if target
        old_director = Bosh::Cli::Client::Director.new(target, credentials, ca_cert: config.ca_cert)
        old_director_uuid = old_director.get_status['uuid'] rescue nil
      else
        old_director_uuid = nil
      end

      new_director_uuid = manifest['director_uuid']

      if old_director_uuid != new_director_uuid
        new_target_url = config.resolve_alias(:target, new_director_uuid)

        if new_target_url.blank?
          err('This manifest references director with UUID ' +
              "#{new_director_uuid}.\n" +
              "You've never targeted it before.\n" +
              'Please find your director IP or hostname and target it first.')
        end

        target_ca_cert = config.ca_cert(new_target_url)
        new_director = Bosh::Cli::Client::Director.new(
          new_target_url, credentials, ca_cert: target_ca_cert)

        status = new_director.get_status

        config.target = new_target_url
        config.target_name = status['name']
        config.target_version = status['version']
        config.target_uuid = status['uuid']
        say("#{'WARNING!'.make_red} Your target has been " +
            "changed to '#{target.make_red}'!")
      end

      say("Deployment set to '#{manifest_filename.make_green}'")
      config.set_deployment(manifest_filename)
      config.save
    end

    # bosh edit deployment
    usage 'edit deployment'
    desc 'Edit current deployment manifest'
    def edit
      deployment_required
      editor = ENV['EDITOR'] || 'vi'
      system("#{editor} #{deployment}")
    end

    # bosh deploy
    usage 'deploy'
    desc 'Deploy according to the currently selected deployment manifest'
    option '--recreate', 'Recreate all VMs in deployment'
    option '--no-redact', 'Redact manifest value changes in deployment'
    option '--skip-drain [job1,job2]', String, 'Skip drain script for either specific or all jobs'
    option '--dry-run', 'Renders job templates without altering deployment'
    option '--fix', 'Recreates vms if they are unresponsive'

    def perform
      auth_required

      recreate = !!options[:recreate]
      redact_diff = !!options[:no_redact].nil?
      dry_run = !!options[:dry_run]
      fix = !!options[:fix]

      manifest = build_manifest

      if manifest.hash['releases']
        manifest.hash['releases'].each do |release|
          if release['url'].blank?
            if release['version'] == 'create'
              err("Expected URL when specifying release version 'create'")
            end
          else
            parsed_uri = URI.parse(release['url'])
            case parsed_uri.scheme
            when 'file'
              if release['version'] == 'create'
                path_is_reasonable!(parsed_uri.path)
                _, info = run_nested_command "create", "release", "--name", release['name'], "--dir", parsed_uri.path, "--timestamp-version", "--force"
                release['version'] = info[:generated_version]
                run_nested_command "upload", "release", "--dir", parsed_uri.path, info[:generated_manifest_path]
              else
                run_nested_command "upload", "release", parsed_uri.path, '--name', release['name'], '--version', release['version'].to_s
              end
            when 'http', 'https'
              err("Path must be a local release directory when version is 'create'") if release['version'] == 'create'
              err("Expected SHA1 when specifying remote URL for release '#{release["name"]}'") if release['sha1'].blank?
              run_nested_command "upload", "release", release['url'], "--sha1", release['sha1'], "--name", release['name'], "--version", release['version'].to_s
            else
              err("Invalid URL format for release '#{release['name']}' with URL '#{release['url']}'. Supported schemes: file, http, https.")
            end
          end
        end
      end

      if manifest.hash['resource_pools']
        manifest.hash['resource_pools'].each do |resource_pool|
          unless resource_pool['stemcell']['url'].blank?
            parsed_uri = URI.parse(resource_pool['stemcell']['url'])
            case parsed_uri.scheme
            when 'file'
              run_nested_command "upload", "stemcell", parsed_uri.path, "--name", resource_pool['stemcell']['name'], "--version", resource_pool['stemcell']['version'].to_s, "--skip-if-exists"
            when 'http', 'https'
              err("Expected SHA1 when specifying remote URL for stemcell '#{resource_pool['stemcell']['name']}'") if resource_pool['stemcell']['sha1'].blank?
              run_nested_command "upload", "stemcell", resource_pool['stemcell']['url'], "--sha1", resource_pool['stemcell']['sha1'],
                "--name", resource_pool['stemcell']['name'], "--version", resource_pool['stemcell']['version'].to_s, "--skip-if-exists"
            else
              err("Invalid URL format for stemcell '#{resource_pool['stemcell']['name']}' with URL '#{resource_pool['stemcell']['url']}'. Supported schemes: file, http, https.")
            end
          end
        end
      end

      manifest = prepare_deployment_manifest(resolve_properties: true, show_state: true)

      context = DeploymentDiff.new(director, manifest).print({redact_diff: redact_diff})
      say('Please review all changes carefully'.make_yellow) if interactive?

      header('Deploying')

      unless confirmed?('Are you sure you want to deploy?')
        cancel_deployment
      end

      deploy_options = { recreate: recreate, context: context, dry_run: dry_run, fix: fix}

      if options.has_key?(:skip_drain)
        # when key is present but no jobs specified OptionParser
        # adds a key with nil value, in that case we want to
        # skip drain for all jobs
        deploy_options[:skip_drain] = options[:skip_drain].nil? ? '*' : options[:skip_drain]
      end

      status, task_id = director.deploy(manifest.yaml, deploy_options)

      task_report(status, task_id, "Deployed '#{manifest.name.make_green}' to '#{target_name.make_green}'")
    end

    # bosh delete deployment
    usage 'delete deployment'
    desc 'Delete deployment'
    option '--force', 'ignore errors while deleting'
    def delete(deployment_name)
      auth_required
      show_current_state(deployment_name)

      force = !!options[:force]

      say("\nYou are going to delete deployment '#{deployment_name}'.".make_red)
      nl
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)

      unless confirmed?
        say('Canceled deleting deployment'.make_green)
        return
      end

      begin
        status, result = director.delete_deployment(deployment_name, :force => force)
        task_report(status, result, "Deleted deployment '#{deployment_name}'")
      rescue Bosh::Cli::ResourceNotFound
        task_report(:done, nil, "Skipped delete of missing deployment '#{deployment_name}'")
      end
    end

    # bosh deployments
    usage 'deployments'
    desc 'Show the list of available deployments'
    def list
      auth_required
      show_current_state

      deployments = director.list_deployments

      err('No deployments') if deployments.empty?

      deployments_table = table do |t|
        t.headings = ['Name', 'Release(s)', 'Stemcell(s)', 'Cloud Config']
        deployments.each do |d|
          t.add_row(row_for_deployments_table(d))
          t.add_separator unless d == deployments.last
        end
      end

      nl
      say(deployments_table)
      nl
      say('Deployments total: %d' % deployments.size)
    end

    # bosh download manifest
    usage 'download manifest'
    desc 'Download deployment manifest locally'
    def download_manifest(deployment_name, save_as = nil)
      auth_required
      show_current_state(deployment_name)

      if save_as && File.exists?(save_as) &&
         !confirmed?("Overwrite '#{save_as}'?")
        err('Please choose another file to save the manifest to')
      end

      deployment = director.get_deployment(deployment_name)

      if save_as
        File.open(save_as, 'w') do |f|
          f.write(deployment['manifest'])
        end
        say("Deployment manifest saved to '#{save_as}'".make_green)
      else
        say(deployment['manifest'])
      end
    end

    private
    def show_current
      config.target = target
      if config.deployment
        if interactive?
          say("Current deployment is '#{config.deployment.make_green}'")
        else
          say(config.deployment)
        end
      else
        err('Deployment not set')
      end
    end

    def row_for_deployments_table(deployment)
      stemcells = names_and_versions_from(deployment['stemcells'])
      releases  = names_and_versions_from(deployment['releases'])

      [deployment['name'], releases.join("\n"), stemcells.join("\n"), deployment.fetch('cloud_config', 'none')]
    end

    def names_and_versions_from(arr)
      arr.map { |hash|
        hash.values_at('name', 'version').join('/')
      }.sort
    end

    def path_is_reasonable!(path)
      #path is actually to a directory, not a file
      unless File.directory?(path)
        err "Path must be a release directory when version is 'create'"
      end
    end

  end
end
