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

        @manifest = YAML.load_file(manifest_file)

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

        created_package_refs = create_packages(new_packages, release_dir)

        existing_package_refs = use_existing_packages(existing_packages, release_dir)


        if @compiled_release
          registered_package_refs = registered_packages.map do |pkg, pkg_meta|
            {
              package: pkg,
              package_meta: pkg_meta,
            }
          end

          all_package_refs = Array(created_package_refs) | Array(existing_package_refs) | registered_package_refs
          create_compiled_packages(all_package_refs, release_dir)
          return
        end

        backfill_source_for_packages(registered_packages, release_dir)
      end

      # @return [boolean] true if sources were added to at least one package; false if the call had no effect.
      def backfill_source_for_packages(packages, release_dir)
        return false if packages.empty?

        had_effect = false
        single_step_stage("Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
          packages.each do |package, package_meta|
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Adding source for package '#{package_desc}'")
            had_effect |= save_package_source_blob(package, package_meta, release_dir)
            package.save
          end
        end

        had_effect
      end

      # Points release DB model to existing packages described by given metadata
      # @param [Array<Array>] packages Existing packages metadata.
      # @return [Array<Hash>] array of registered package models and their metadata, empty if no packages were changed.
      def use_existing_packages(packages, release_dir)
        return [] if packages.empty?

        package_refs = []

        single_step_stage("Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
          packages.each do |package, package_meta|
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Using existing package '#{package_desc}'")
            register_package(package)

            if compiled_release
              package_refs << {
                package: package,
                package_meta: package_meta,
              }
            end

            if source_release && (package.blobstore_id.nil? || @fix)
              save_package_source_blob(package, package_meta, release_dir)
              package.save
            end
          end
        end

        package_refs
      end

      # Creates packages using provided metadata
      # @param [Array<Hash>] packages Packages metadata
      # @param [String] release_dir local path to the unpacked release
      # @return [Array<Hash>, boolean] array of package models and their metadata, empty if no packages were changed.
      def create_packages(package_metas, release_dir)
        return [] if package_metas.empty?

        package_refs = []

        event_log_stage = Config.event_log.begin_stage('Creating new packages', package_metas.size)

        package_metas.each do |package_meta|
          package_desc = "#{package_meta['name']}/#{package_meta['version']}"
          package = nil
          event_log_stage.advance_and_track(package_desc) do
            logger.info("Creating new package '#{package_desc}'")
            package = create_package(package_meta, release_dir)
            register_package(package)
          end

          next unless @compiled_release

          package_refs << {
            package: package,
            package_meta: package_meta,
          }
        end

        package_refs
      end

      # @return [boolean] true if at least one job was created; false if the call had no effect.
      def create_compiled_packages(all_compiled_packages, release_dir)
        return false if all_compiled_packages.nil?

        event_log_stage = Config.event_log.begin_stage('Creating new compiled packages', all_compiled_packages.size)
        had_effect = false

        all_compiled_packages.each do |compiled_package_spec|
          package = compiled_package_spec[:package]
          stemcell = Models::CompiledPackage.split_stemcell_os_and_version(compiled_package_spec[:package_meta]['stemcell'])
          compiled_pkg_tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")

          stemcell_os = stemcell[:os]
          stemcell_version = stemcell[:version]

          existing_compiled_packages = find_compiled_packages(package.id, stemcell_os, stemcell_version, dependency_key(package))

          if existing_compiled_packages.empty?
            package_desc = "#{package.name}/#{package.version} for #{stemcell_os}/#{stemcell_version}"
            event_log_stage.advance_and_track(package_desc) do
              other_compiled_packages = compiled_packages_matching(package, stemcell)
              if @fix
                other_compiled_packages.each do |other_compiled_package|
                  fix_compiled_package(other_compiled_package, compiled_pkg_tgz)
                end
              end
              package_sha1 = compiled_package_spec[:package_meta]['compiled_package_sha1']
              create_compiled_package(package, package_sha1, stemcell_os, stemcell_version, release_dir, other_compiled_packages.first)
              had_effect = true
            end
          elsif @fix
            existing_compiled_package = existing_compiled_packages.first
            fix_compiled_package(existing_compiled_package, compiled_pkg_tgz)
          end
        end

        had_effect
      end

      def compiled_packages_matching(package, stemcell)
        other_compiled_packages = []
        dependency_key = dependency_key(package)
        packages = Models::Package.where(fingerprint: package.fingerprint).order_by(:id).all
        packages.each do |pkg|
          other_compiled_packages.concat(find_compiled_packages(pkg.id, stemcell[:os], stemcell[:version], dependency_key).all)
        end
        other_compiled_packages
      end

      def create_compiled_package(package, package_sha1, stemcell_os, stemcell_version, release_dir, other_compiled_package)
        if other_compiled_package.nil?
          tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")
          validate_tgz(tgz, "#{package.name}.tgz")
          blobstore_id = BlobUtil.create_blob(tgz)
          sha1 = package_sha1
        else
          blobstore_id = BlobUtil.copy_blob(other_compiled_package.blobstore_id)
          sha1 = other_compiled_package.sha1
        end

        compiled_package = Models::CompiledPackage.new
        compiled_package.blobstore_id = blobstore_id
        compiled_package.sha1 = sha1
        release_version_model_dependency_key = dependency_key(package)
        if release_version_model_dependency_key != CompiledRelease::Manifest.new(@manifest).dependency_key(package.name)
          raise ReleasePackageDependencyKeyMismatch, "The uploaded release contains package dependencies in '#{package.name}' that do not match database records."
        end

        compiled_package.dependency_key = release_version_model_dependency_key

        compiled_package.build = Models::CompiledPackage.generate_build_number(package, stemcell_os, stemcell_version)
        compiled_package.package_id = package.id

        compiled_package.stemcell_os = stemcell_os
        compiled_package.stemcell_version = stemcell_version

        compiled_package.save
      end

      # Creates package in DB according to given metadata
      # @param [Hash] package_meta Package metadata
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def create_package(package_meta, release_dir)
        name = package_meta['name']
        version = package_meta['version']

        package_attrs = {
          release: @release_model,
          name: name,
          sha1: nil,
          blobstore_id: nil,
          fingerprint: package_meta['fingerprint'],
          version: version,
        }

        package = Models::Package.new(package_attrs)
        package.dependency_set = package_meta['dependencies']

        save_package_source_blob(package, package_meta, release_dir) unless @compiled_release

        package.save
      end

      # @return [boolean] true if a new blob was created; false otherwise
      def save_package_source_blob(package, package_meta, release_dir)
        name = package_meta['name']
        version = package_meta['version']
        existing_blob = package_meta['blobstore_id']
        sha1 = package_meta['sha1']
        desc = "package '#{name}/#{version}'"
        package_tgz = File.join(release_dir, 'packages', "#{name}.tgz")

        if @fix
          package.sha1 = sha1

          unless package.blobstore_id.nil?
            delete_compiled_packages(package)
            validate_tgz(package_tgz, desc)
            fix_package(package, package_tgz)
            return true
          end

          if existing_blob
            pkg = Models::Package.where(blobstore_id: existing_blob).first
            delete_compiled_packages(package)
            fix_package(pkg, package_tgz)
            package.blobstore_id = BlobUtil.copy_blob(pkg.blobstore_id)
            return true
          end
        else
          return false unless package.blobstore_id.nil?

          package.sha1 = sha1

          if existing_blob
            logger.info("Creating #{desc} from existing blob #{existing_blob}")
            package.blobstore_id = BlobUtil.copy_blob(existing_blob)
            return true
          end
        end

        logger.info("Creating #{desc} from provided bits")
        validate_tgz(package_tgz, desc)
        package.blobstore_id = BlobUtil.create_blob(package_tgz)

        true
      end

      def validate_tgz(tgz, desc)
        result = Bosh::Exec.sh("tar -tzf #{tgz} 2>&1", on_error: :return)
        if result.failed?
          logger.error("Extracting #{desc} archive failed, tar returned #{result.exit_status}, output: #{result.output}")
          raise PackageInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
        end
      end

      # Marks package model as used by release version model
      # @param [Models::Package] package Package model
      # @return [void]
      def register_package(package)
        @release_version_model.add_package(package)
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

      def dependency_key(package)
        KeyGenerator.new.dependency_key_from_models(package, @release_version_model)
      end

      def find_compiled_packages(pkg_id, stemcell_os, stemcell_version, dependency_key)
        Models::CompiledPackage.where(
          package_id: pkg_id,
          stemcell_os: stemcell_os,
          stemcell_version: stemcell_version,
          dependency_key: dependency_key,
        )
      end

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

      def fix_package(package, package_tgz)
        begin
          logger.info("Deleting package '#{package.name}/#{package.version}'")
          BlobUtil.delete_blob(package.blobstore_id)
        rescue Bosh::Blobstore::BlobstoreError => e
          logger.info("Error deleting blob '#{package.blobstore_id}, #{package.name}/#{package.version}': #{e.inspect}")
        end
        package.blobstore_id = BlobUtil.create_blob(package_tgz)
        logger.info("Re-created package '#{package.name}/#{package.version}' \
with blobstore_id '#{package.blobstore_id}'")
        package.save
      end

      def delete_compiled_packages(package)
        package.compiled_packages.each do |compiled_pkg|
          logger.info("Deleting compiled package '#{compiled_pkg.name}' for \
'#{compiled_pkg.stemcell_os}/#{compiled_pkg.stemcell_version}' with blobstore_id '#{compiled_pkg.blobstore_id}'")
          begin
            logger.info("Deleting compiled package '#{compiled_pkg.name}'")
            BlobUtil.delete_blob(compiled_pkg.blobstore_id)
          rescue Bosh::Blobstore::BlobstoreError => e
            logger.info("Error deleting compiled package \
'#{compiled_pkg.blobstore_id}/#{compiled_pkg.name}' #{e.inspect}")
          end
          compiled_pkg.destroy
        end
      end

      def fix_compiled_package(compiled_pkg, compiled_pkg_tgz)
        begin
          logger.info("Deleting compiled package '#{compiled_pkg.name}/#{compiled_pkg.version}' for \
'#{compiled_pkg.stemcell_os}/#{compiled_pkg.stemcell_version}' with blobstore_id '#{compiled_pkg.blobstore_id}'")
          BlobUtil.delete_blob compiled_pkg.blobstore_id
        rescue Bosh::Blobstore::BlobstoreError => e
          logger.info("Error deleting compiled package '#{compiled_pkg.name}' \
with blobstore_id '#{compiled_pkg.blobstore_id}' #{e.inspect}")
        end
        compiled_pkg.blobstore_id = BlobUtil.create_blob(compiled_pkg_tgz)
        logger.info("Re-created compiled package '#{compiled_pkg.name}/#{compiled_pkg.version}' \
with blobstore_id '#{compiled_pkg.blobstore_id}'")
        compiled_pkg.save
      end
    end
  end
end
