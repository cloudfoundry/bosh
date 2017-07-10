module Bosh::Director
  class ReleaseJob

    attr_accessor :packages

    def initialize(job_meta, release_model, release_dir, logger)
      @name = job_meta['name']
      @version = job_meta['version']
      @sha1 = job_meta['sha1']
      @fingerprint = job_meta['fingerprint']

      @release_model = release_model
      @release_dir = release_dir
      @logger = logger
    end

    def update(template)
      template.release = @release_model
      template.name = @name
      template.sha1 = @sha1
      template.fingerprint = @fingerprint
      template.version = @version

      unpack

      job_manifest = load_manifest
      validate_templates(job_manifest)
      validate_monit

      if template.blobstore_id
        begin
          @logger.info("Deleting blob for template '#{@name}/#{@version}' with blobstore_id '#{template.blobstore_id}'")
          BlobUtil.delete_blob(template.blobstore_id)
          template.blobstore_id = nil
        rescue Bosh::Blobstore::BlobstoreError => e
          @logger.info("Error deleting blob for template '#{@name}/#{@version}' with blobstore_id '#{template.blobstore_id}': #{e.inspect}")
        end
      end

      template.blobstore_id = BlobUtil.create_blob(job_tgz)
      template.package_names = parse_package_names(job_manifest)

      validate_logs(job_manifest)
      template.logs = job_manifest['logs']

      validate_properties(job_manifest)
      template.properties = job_manifest['properties']

      validate_links(job_manifest)
      template.provides = job_manifest['provides'] if job_manifest['provides']
      template.consumes = job_manifest['consumes'] if job_manifest['consumes']

      template.templates = job_manifest['templates']

      template.save
    end

    private

    def unpack
      FileUtils.mkdir_p(job_dir)

      desc = "job '#{@name}/#{@version}'"
      result = Bosh::Exec.sh("tar -C #{job_dir} -xzf #{job_tgz} 2>&1", :on_error => :return)
      if result.failed?
        @logger.error("Extracting #{desc} archive failed in dir #{job_dir}, " +
          "tar returned #{result.exit_status}, " +
          "output: #{result.output}")
        raise JobInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
      end
    end

    def job_tgz
      @job_tgz ||= File.join(@release_dir, 'jobs', "#{@name}.tgz")
    end

    def job_dir
      @job_dir ||= File.join(@release_dir, 'jobs', @name)
    end

    def load_manifest
      manifest_file = File.join(job_dir, 'job.MF')
      unless File.file?(manifest_file)
        raise JobMissingManifest,
          "Missing job manifest for '#{@name}'"
      end

      YAML.load_file(manifest_file)
    end

    def validate_templates(job_manifest)
      if job_manifest['templates']
        job_manifest['templates'].each_key do |relative_path|
          path = File.join(job_dir, 'templates', relative_path)
          unless File.file?(path)
            raise JobMissingTemplateFile,
              "Missing template file '#{relative_path}' for job '#{@name}'"
          end
        end
      end
    end

    def validate_monit
      main_monit_file = File.join(job_dir, 'monit')
      aux_monit_files = Dir.glob(File.join(job_dir, '*.monit'))

      unless File.exists?(main_monit_file) || aux_monit_files.size > 0
        raise JobMissingMonit, "Job '#{@name}' is missing monit file"
      end
    end

    def parse_package_names(job_manifest)
      if job_manifest['packages'] && !job_manifest['packages'].is_a?(Array)
        raise JobInvalidPackageSpec, "Job '#{@name}' has invalid package spec format"
      end
      job_manifest['packages'] || []
    end

    def validate_logs(job_manifest)
      if job_manifest['logs']
        unless job_manifest['logs'].is_a?(Hash)
          raise JobInvalidLogSpec,
            "Job '#{@name}' has invalid logs spec format"
        end
      end
    end

    def validate_properties(job_manifest)
      if job_manifest['properties']
        unless job_manifest['properties'].is_a?(Hash)
          raise JobInvalidPropertySpec,
            "Job '#{@name}' has invalid properties spec format"
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
          "Job '#{@name}' has invalid spec format: '#{kind}' must be an array of hashes with name and type"
      end

      parsed_links = {}
      links.each do |link_spec|
        parsed_link = DeploymentPlan::TemplateLink.parse(kind, link_spec)
        if parsed_links[parsed_link.name]
          raise JobDuplicateLinkName,
            "Job '#{@name}' '#{kind}' specifies links with duplicate name '#{parsed_link.name}'"
        end

        parsed_links[parsed_link.name] = true
      end
    end
  end
end
