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

      validate_templates(job_manifest)
      validate_monit
      validate_logs(job_manifest)
      validate_properties(job_manifest)
      validate_links(job_manifest)

      template = Models::Template.find_or_init_from_release_meta(
        release: @release_model,
        job_meta: @job_meta,
        job_manifest: job_manifest,
      )

      if template.blobstore_id
        begin
          @logger.info("Deleting blob for template '#{name}/#{@version}' with blobstore_id '#{template.blobstore_id}'")
          BlobUtil.delete_blob(template.blobstore_id)
          template.blobstore_id = nil
        rescue Bosh::Blobstore::BlobstoreError => e
          @logger.info("Error deleting blob for template '#{name}/#{@version}' with blobstore_id '#{template.blobstore_id}': #{e.inspect}")
        end
      end

      template.blobstore_id = BlobUtil.create_blob(job_tgz)

      template.save
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

      YAML.load_file(manifest_file)
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

      unless File.exists?(main_monit_file) || aux_monit_files.size > 0
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
      parse_links(job_manifest['provides'], 'provides') if job_manifest['provides']
      parse_links(job_manifest['consumes'], 'consumes') if job_manifest['consumes']
    end

    def parse_links(links, kind)
      if !links.is_a?(Array)
        raise JobInvalidLinkSpec,
          "Job '#{name}' has invalid spec format: '#{kind}' must be an array of hashes with name and type"
      end

      parsed_links = {}
      links.each do |link_spec|
        parsed_link = DeploymentPlan::TemplateLink.parse(kind, link_spec)
        if parsed_links[parsed_link.name]
          raise JobDuplicateLinkName,
            "Job '#{name}' '#{kind}' specifies links with duplicate name '#{parsed_link.name}'"
        end

        parsed_links[parsed_link.name] = true
      end
    end

    def name
      @job_meta['name']
    end
  end
end
