require 'securerandom'
require 'common/version/release_version'

module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      include LockHelper
      include DownloadHelper

      @queue = :normal
      @local_fs = true

      @compiled_release = false

      attr_accessor :release_model
      attr_reader :release_path, :release_url, :sha1, :fix

      def self.job_type
        :update_release
      end

      # @param [String] release_path local path or remote url of the release archive
      # @param [Hash] options Release update options
      def initialize(release_path, options = {})
        if options['remote']
          # file will be downloaded to the release_path
          @release_path = File.join(Dir.tmpdir, "release-#{SecureRandom.uuid}")
          @release_url = release_path
          @sha1 = options['sha1']
        else
          # file already exists at the release_path
          @release_path = release_path
        end
        @multi_digest_verifier = BoshDigest::MultiDigest.new(logger)
        @rebase = !!options['rebase']
        @fix = !!options['fix']
      end

      # Extracts release tarball, verifies release manifest and saves release in DB
      # @return [void]
      def perform
        logger.info('Processing update release')
        logger.info('Release rebase will be performed') if @rebase

        single_step_stage('Downloading remote release') { download_remote_release } if release_url

        single_step_stage('Verifying remote release') { verify_sha } if sha1

        release_dir = nil
        single_step_stage('Extracting release') { release_dir = extract_release }

        single_step_stage('Verifying manifest') { verify_manifest(release_dir) }

        with_release_lock(@name) { process_release(release_dir) }

        "Created release '#{@name}/#{@version}'"
      rescue Exception => e
        raise e
      ensure
        FileUtils.rm_rf(release_dir) if release_dir
        FileUtils.rm_rf(release_path) if release_path
      end

      def download_remote_release
        download_remote_file('release', release_url, release_path)
      end

      # Extracts release tarball
      # @return [void]
      def extract_release
        release_dir = Dir.mktmpdir

        result = Bosh::Exec.sh("tar -C #{release_dir} -xzf #{release_path} 2>&1", on_error: :return)
        if result.failed?
          logger.error("Failed to extract release archive '#{release_path}' into dir '#{release_dir}', tar returned #{result.exit_status}, output: #{result.output})")
          FileUtils.rm_rf(release_dir)
          raise ReleaseInvalidArchive, 'Extracting release archive failed. Check task debug log for details.'
        end

        release_dir
      end

      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def verify_manifest(release_dir)
        manifest_file = File.join(release_dir, 'release.MF')
        raise ReleaseManifestNotFound, 'Release manifest not found' unless File.file?(manifest_file)

        @manifest = YAML.load_file(manifest_file, aliases: true)

        # handle compiled_release case
        @compiled_release = !!@manifest['compiled_packages']
        @packages_folder = @compiled_release ? 'compiled_packages' : 'packages'

        normalize_manifest

        @name = @manifest['name']

        begin
          @version = Bosh::Common::Version::ReleaseVersion.parse(@manifest['version'])
          logger.info("Formatted version '#{@manifest['version']}' => '#{@version}'") unless @version.to_s == @manifest['version']
        rescue SemiSemantic::ParseError
          raise ReleaseVersionInvalid, "Release version invalid: #{@manifest['version']}"
        end

        @commit_hash = @manifest.fetch('commit_hash', nil)
        @uncommitted_changes = @manifest.fetch('uncommitted_changes', nil)
      end

      def verify_sha
        @multi_digest_verifier.verify(release_path, sha1)
      rescue Bosh::Director::BoshDigest::ShaMismatchError => e
        raise Bosh::Director::ReleaseSha1DoesNotMatch, e
      end

      def compiled_release
        raise "Don't know what kind of release we have until verify_release is called" unless @manifest

        @compiled_release
      end

      def source_release
        !compiled_release
      end

      # Processes uploaded release, creates jobs and packages in DB if needed
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def process_release(release_dir)
        @release_model = Models::Release.find_or_create(name: @name)

        @version = next_release_version if @rebase

        release_is_new = false
        @release_version_model = Models::ReleaseVersion.find_or_create(release: @release_model, version: @version.to_s) do
          release_is_new = true
        end

        if release_is_new
          @release_version_model.uncommitted_changes = @uncommitted_changes if @uncommitted_changes
          @release_version_model.commit_hash = @commit_hash if @commit_hash
          @release_version_model.save
        elsif @release_version_model.commit_hash != @commit_hash ||
              @release_version_model.uncommitted_changes != @uncommitted_changes
          raise ReleaseVersionCommitHashMismatch,
                "release '#{@name}/#{@version}' has already been uploaded with commit_hash as " \
                "'#{@release_version_model.commit_hash}' and uncommitted_changes as '#{@uncommitted_changes}'"
        else
          @fix = true if @release_version_model.update_completed == false
          @release_version_model.update_completed = false
          @release_version_model.save
        end

        single_step_stage('Resolving package dependencies') do
          resolve_package_dependencies(manifest_packages)
        end

        process_packages(release_dir)
        process_jobs(release_dir)

        event_log_stage = Config.event_log.begin_stage(
          @compiled_release ? 'Compiled Release has been created' : 'Release has been created',
          1,
        )
        event_log_stage.advance_and_track("#{@name}/#{@version}") {}

        @release_version_model.update_completed = true
        @release_version_model.save
      end

      # Normalizes release manifest, so all names, versions, and checksums are Strings.
      # @return [void]
      def normalize_manifest
        Bosh::Director.hash_string_vals(@manifest, 'name', 'version')

        manifest_packages.each { |p| Bosh::Director.hash_string_vals(p, 'name', 'version', 'sha1') }
        manifest_jobs.each { |j| Bosh::Director.hash_string_vals(j, 'name', 'version', 'sha1') }
      end

      # Resolves package dependencies, makes sure there are no cycles
      # and all dependencies are present
      # @return [void]
      def resolve_package_dependencies(packages)
        packages_by_name = {}
        packages.each do |package|
          packages_by_name[package['name']] = package
          package['dependencies'] ||= []
        end
        logger.info("Resolving package dependencies for #{packages_by_name.keys.inspect}")

        dependency_lookup = lambda do |package_name|
          packages_by_name[package_name]['dependencies']
        end
        result = Bosh::Director::CycleHelper.check_for_cycle(packages_by_name.keys, connected_vertices: true, &dependency_lookup)

        packages.each do |package|
          name = package['name']
          dependencies = package['dependencies']
          all_dependencies = result[:connected_vertices][name]
          logger.info("Resolved package dependencies for '#{name}': #{dependencies.pretty_inspect} => #{all_dependencies.pretty_inspect}")
        end
      end

      # Finds all package definitions in the manifest and sorts them into two
      # buckets: new and existing packages, then creates new packages and points
      # current release version to the existing packages.
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def process_packages(release_dir)
        new_packages, existing_packages, registered_packages = PackageProcessor.process(
          @release_version_model,
          @release_model,
          @name,
          @version,
          manifest_packages,
          logger,
        )

        PackagePersister.persist(
          new_packages:          new_packages,
          existing_packages:     existing_packages,
          registered_packages:   registered_packages,
          compiled_release:      @compiled_release,
          release_dir:           release_dir,
          fix:                   @fix,
          manifest:              @manifest,
          release_version_model: @release_version_model,
          release_model:         @release_model,
        )
      end

      # Finds job template definitions in release manifest and sorts them into
      # two buckets: new and existing job templates, then creates new job
      # template records in the database and points release version to existing ones.
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def process_jobs(release_dir)
        logger.info('Checking for new jobs in release')

        new_jobs = []
        existing_jobs = []
        manifest_jobs = @manifest['jobs'] || []

        manifest_jobs.each do |job_meta|
          # Checking whether we might have the same bits somewhere
          @release_version_model.templates.select { |t| t.name == job_meta['name'] }.each do |tmpl|
            next unless tmpl.fingerprint != job_meta['fingerprint']

            raise(
              ReleaseExistingJobFingerprintMismatch,
              "job '#{job_meta['name']}' had different fingerprint in previously uploaded release '#{@name}/#{@version}'",
            )
          end

          jobs = Models::Template.where(fingerprint: job_meta['fingerprint']).all

          template = jobs.find do |job|
            job.release_id == @release_model.id &&
              job.name == job_meta['name'] &&
              job.version == job_meta['version']
          end

          if template.nil?
            new_jobs << job_meta
          else
            existing_jobs << [template, job_meta]
          end
        end

        did_something = create_jobs(new_jobs, release_dir)
        did_something |= use_existing_jobs(existing_jobs, release_dir)

        did_something
      end

      # @return [boolean] true if at least one job was created; false if the call had no effect.
      def create_jobs(jobs, release_dir)
        return false if jobs.empty?

        event_log_stage = Config.event_log.begin_stage('Creating new jobs', jobs.size)
        jobs.each do |job_meta|
          job_desc = "#{job_meta['name']}/#{job_meta['version']}"
          event_log_stage.advance_and_track(job_desc) do
            logger.info("Creating new template '#{job_desc}'")
            template = create_job(job_meta, release_dir)
            register_template(template)
          end
        end

        true
      end

      def create_job(job_meta, release_dir)
        release_job = ReleaseJob.new(job_meta, @release_model, release_dir, logger)
        logger.info("Creating job template '#{job_meta['name']}/#{job_meta['version']}' " \
            'from provided bits')
        release_job.update
      end

      # @param [Array<Array>] jobs Existing jobs metadata
      # @return [boolean] true if at least one job was tied to the release version; false if the call had no effect.
      def use_existing_jobs(jobs, release_dir)
        return false if jobs.empty?

        single_step_stage("Processing #{jobs.size} existing job#{'s' if jobs.size > 1}") do
          jobs.each do |template, job_meta|
            job_desc = "#{template.name}/#{template.version}"

            if @fix
              logger.info("Fixing existing job '#{job_desc}'")
              release_job = ReleaseJob.new(job_meta, @release_model, release_dir, logger)
              release_job.update
            else
              logger.info("Using existing job '#{job_desc}'")
            end

            register_template(template) unless template.release_versions.include? @release_version_model
          end
        end

        true
      end

      private

      # Marks job template model as being used by release version
      # @param [Models::Template] template Job template model
      # @return [void]
      def register_template(template)
        @release_version_model.add_template(template)
      end

      def manifest_packages
        @manifest[@packages_folder] || []
      end

      def manifest_jobs
        @manifest['jobs'] || []
      end

      # Returns the next release version (to be used for rebased release)
      # @return [String]
      def next_release_version
        attrs = { release_id: @release_model.id }
        models = Models::ReleaseVersion.filter(attrs).all
        strings = models.map(&:version)
        list = Bosh::Common::Version::ReleaseVersionList.parse(strings)
        list.rebase(@version)
      end
    end
  end
end
