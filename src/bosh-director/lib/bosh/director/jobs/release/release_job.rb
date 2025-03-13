module Bosh::Director
  class ReleaseJob

    attr_accessor :packages

    def initialize(job_meta, release_model, release_dir, logger)
      @job_meta = job_meta
      @release_model = release_model
      @release_dir = release_dir
      @logger = logger
    end

    def update
      unpack

      job_manifest = load_manifest

      validate_name(job_manifest)
      validate_templates(job_manifest)
      validate_monit
      validate_logs(job_manifest)
      validate_properties(job_manifest)
      validate_links(job_manifest)

      job_model = Models::Template.find_or_init_from_release_meta(
        release: @release_model,
        job_meta: @job_meta,
        job_manifest: job_manifest,
      )

      if job_model.blobstore_id
        begin
          @logger.info("Deleting blob for job '#{name}/#{@version}' with blobstore_id '#{job_model.blobstore_id}'")
          BlobUtil.delete_blob(job_model.blobstore_id)
          job_model.blobstore_id = nil
        rescue Bosh::Director::Blobstore::BlobstoreError => e
          @logger.info("Error deleting blob for job '#{name}/#{@version}' with blobstore_id '#{job_model.blobstore_id}': #{e.inspect}")
        end
      end

      job_model.blobstore_id = BlobUtil.create_blob(job_tgz)

      job_model.save
    end

    private

    def unpack
      FileUtils.mkdir_p(job_dir)

      desc = "job '#{name}/#{@version}'"
      result = Bosh::Exec.sh("tar -C #{job_dir} -xzf #{job_tgz} 2>&1", :on_error => :return)
      if result.failed?
        @logger.error("Extracting #{desc} archive failed in dir #{job_dir}, " +
          "tar returned #{result.exit_status}, " +
          "output: #{result.output}")
        raise JobInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
      end
    end

    def job_tgz
      @job_tgz ||= File.join(@release_dir, 'jobs', "#{name}.tgz")
    end

    def job_dir
      @job_dir ||= File.join(@release_dir, 'jobs', name)
    end

    def load_manifest
      manifest_file = File.join(job_dir, 'job.MF')
      unless File.file?(manifest_file)
        raise JobMissingManifest,
          "Missing job manifest for '#{name}'"
      end

      YAML.load_file(manifest_file, aliases: true)
    end

    def validate_name(job_manifest)
      unless name == job_manifest['name']
        raise JobInvalidName, "Inconsistent name for job '#{name}'" +
          "(exptected: '#{name}', got: '#{job_manifest['name']}')"
      end
    end

    def validate_templates(job_manifest)
      if job_manifest['templates']
        job_manifest['templates'].each_key do |relative_path|
          path = File.join(job_dir, 'templates', relative_path)
          unless File.file?(path)
            raise JobMissingTemplateFile,
              "Missing template file '#{relative_path}' for job '#{name}'"
          end
        end
      end
    end

    def validate_monit
      main_monit_file = File.join(job_dir, 'monit')
      aux_monit_files = Dir.glob(File.join(job_dir, '*.monit'))

      unless File.exist?(main_monit_file) || aux_monit_files.size > 0
        raise JobMissingMonit, "Job '#{name}' is missing monit file"
      end
    end

    def validate_logs(job_manifest)
      if job_manifest['logs']
        unless job_manifest['logs'].is_a?(Hash)
          raise JobInvalidLogSpec,
            "Job '#{name}' has invalid logs spec format"
        end
      end
    end

    def validate_properties(job_manifest)
      if job_manifest['properties']
        unless job_manifest['properties'].is_a?(Hash)
          raise JobInvalidPropertySpec,
            "Job '#{name}' has invalid properties spec format"
        end
      end
    end

    def validate_links(job_manifest)
      validate_provide_links(job_manifest['provides'])
      validate_consume_links(job_manifest['consumes'])
    end

    def validate_provide_links(provider_links)
      return if provider_links.nil?
      raise JobInvalidLinkSpec, "Job '#{name}' has invalid spec format: 'provides' must be an array of hashes with name and type" unless provider_links.is_a?(Array)

      parsed_links = {}
      provider_links.each do |spec|
        raise JobInvalidLinkSpec, "Provides section in the release spec must be a list of hashes" unless spec.is_a?(Hash)

        if !spec.has_key?('type') || !spec.has_key?('name')
          raise JobInvalidLinkSpec, "Each provides item in the provides section of the release spec must contain 'name' and 'type'"
        end

        provider_name = spec['name']

        if spec.has_key?('optional')
          raise JobInvalidLinkSpec, "Link '#{provider_name}' of type '#{spec['type']}' is a provides link, not allowed to have 'optional' key"
        end

        if parsed_links[provider_name]
          raise JobDuplicateLinkName, "Job '#{name}' specifies duplicate provides link with name '#{provider_name}'"
        end
        parsed_links[provider_name] = true
      end
    end

    def validate_consume_links(consume_links)
      return if consume_links.nil?
      raise JobInvalidLinkSpec, "Job '#{name}' has invalid spec format: 'consumes' must be an array of hashes with name and type" unless consume_links.is_a?(Array)

      parsed_links = {}
      consume_links.each do |spec|
        raise JobInvalidLinkSpec, "Consumes section in the release spec must be a list of hashes" unless spec.is_a?(Hash)

        if !spec.has_key?('type') || !spec.has_key?('name')
          raise JobInvalidLinkSpec, "Each consumes item in the consumes section of the release spec must contain 'name' and 'type'"
        end

        consumer_name = spec['name']

        if parsed_links[consumer_name]
          raise JobDuplicateLinkName, "Job '#{name}' specifies duplicate consumes link with name '#{consumer_name}'"
        end
        parsed_links[consumer_name] = true
      end
    end

    def name
      @job_meta['name']
    end
  end
end
