require 'securerandom'
require 'common/version/release_version'

module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      include LockHelper
      include DownloadHelper

      @queue = :normal
      @compiled_release = false

      attr_accessor :release_model

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
        else
          # file already exists at the release_path
          @release_path = release_path
        end

        @release_model, @release_version_model, @manifest, @name, @version = nil, nil, nil, nil, nil

        @rebase = !!options['rebase']
      end

      # Extracts release tarball, verifies release manifest and saves release in DB
      # @return [void]
      def perform
        logger.info("Processing update release")
        logger.info("Release rebase will be performed") if @rebase

        single_step_stage("Downloading remote release") { download_remote_release } if @release_url

        release_dir = nil
        single_step_stage("Extracting release") { release_dir = extract_release }

        single_step_stage("Verifying manifest") { verify_manifest(release_dir) }

        with_release_lock(@name) { process_release(release_dir) }

        "Created release `#{@name}/#{@version}'"

      rescue Exception => e
        raise e

      ensure
        FileUtils.rm_rf(release_dir) if release_dir
        FileUtils.rm_rf(@release_path) if @release_path
      end

      def download_remote_release
        download_remote_file('release', @release_url, @release_path)
      end

      # Extracts release tarball
      # @return [void]
      def extract_release
        release_dir = Dir.mktmpdir

        result = Bosh::Exec.sh("tar -C #{release_dir} -xzf #{@release_path} 2>&1", :on_error => :return)
        if result.failed?
          logger.error("Failed to extract release archive '#{@release_path}' into dir '#{release_dir}', tar returned #{result.exit_status}, output: #{result.output})")
          FileUtils.rm_rf(release_dir)
          raise ReleaseInvalidArchive, "Extracting release archive failed. Check task debug log for details."
        end

        release_dir
      end

      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def verify_manifest(release_dir)
        manifest_file = File.join(release_dir, "release.MF")
        raise ReleaseManifestNotFound, "Release manifest not found" unless File.file?(manifest_file)

        @manifest = Psych.load_file(manifest_file)

        #handle compiled_release case
        @compiled_release = !!@manifest["compiled_packages"]
        @packages_folder = @compiled_release ? "compiled_packages" : "packages"

        normalize_manifest

        @name = @manifest["name"]

        begin
          @version = Bosh::Common::Version::ReleaseVersion.parse(@manifest["version"])
          logger.info("Formatted version '#{@manifest["version"]}' => '#{@version}'") unless @version == @manifest["version"]
        rescue SemiSemantic::ParseError
          raise ReleaseVersionInvalid, "Release version invalid: #{@manifest["version"]}"
        end

        @commit_hash = @manifest.fetch("commit_hash", nil)
        @uncommitted_changes = @manifest.fetch("uncommitted_changes", nil)
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
        @release_model = Models::Release.find_or_create(:name => @name)

        @version = next_release_version if @rebase

        version_attrs = { :release => @release_model, :version => @version.to_s }

        release_is_new = false
        @release_version_model = Models::ReleaseVersion.find_or_create(version_attrs){ release_is_new = true }

        if release_is_new
          @release_version_model.uncommitted_changes = @uncommitted_changes if @uncommitted_changes
          @release_version_model.commit_hash = @commit_hash if @commit_hash
          @release_version_model.save
        else
          if @release_version_model.commit_hash != @commit_hash || @release_version_model.uncommitted_changes != @uncommitted_changes
            raise ReleaseVersionCommitHashMismatch, "release `#{@name}/#{@version}' has already been uploaded with commit_hash as `#{@commit_hash}' and uncommitted_changes as `#{@uncommitted_changes}'"
          end
        end

        single_step_stage("Resolving package dependencies") do
          resolve_package_dependencies(@manifest[@packages_folder])
        end

        @packages = {}
        process_packages(release_dir)
        process_jobs(release_dir)

        event_log.begin_stage(@compiled_release ? "Compiled Release has been created" : "Release has been created", 1)
        event_log.track("#{@name}/#{@version}") {}
      end

      # Normalizes release manifest, so all names, versions, and checksums are Strings.
      # @return [void]
      def normalize_manifest
        Bosh::Director.hash_string_vals(@manifest, 'name', 'version')

        @manifest[@packages_folder].each { |p| Bosh::Director.hash_string_vals(p, 'name', 'version', 'sha1') }
        @manifest['jobs'].each { |j| Bosh::Director.hash_string_vals(j, 'name', 'version', 'sha1') }
      end

      # Resolves package dependencies, makes sure there are no cycles
      # and all dependencies are present
      # @return [void]
      def resolve_package_dependencies(packages)
        packages_by_name = {}
        packages.each do |package|
          packages_by_name[package["name"]] = package
          package["dependencies"] ||= []
        end
        logger.info("Resolving package dependencies for #{packages_by_name.keys.inspect}")

        dependency_lookup = lambda do |package_name|
          packages_by_name[package_name]["dependencies"]
        end
        result = Bosh::Director::CycleHelper.check_for_cycle(packages_by_name.keys, :connected_vertices => true, &dependency_lookup)

        packages.each do |package|
          name = package["name"]
          dependencies = package["dependencies"]
          all_dependencies = result[:connected_vertices][name]
          logger.info("Resolved package dependencies for `#{name}': #{dependencies.pretty_inspect} => #{all_dependencies.pretty_inspect}")
        end
      end

      # Finds all package definitions in the manifest and sorts them into two
      # buckets: new and existing packages, then creates new packages and points
      # current release version to the existing packages.
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def process_packages(release_dir)
        logger.info("Checking for new packages in release")

        new_packages = []
        existing_packages = []
        registered_packages = []

        @manifest[@packages_folder].each do |package_meta|
          # Checking whether we might have the same bits somewhere (in any release, not just the one being uploaded)
          @release_version_model.packages.select { |pv| pv.name == package_meta['name'] }.each do |package|
            if package.fingerprint != package_meta['fingerprint']
              raise ReleaseInvalidPackage, "package `#{package_meta['name']}' had different fingerprint in previously uploaded release `#{@name}/#{@version}'"
            end
          end

          packages = Models::Package.where(fingerprint: package_meta["fingerprint"]).all

          if packages.empty?
            new_packages << package_meta
            next
          end

          existing_package = packages.find do |package|
            package.release_id == @release_model.id &&
            package.name == package_meta["name"] &&
            package.version == package_meta["version"]
          end

          if existing_package
            # clean up 'broken' dependency_set (a bug was including transitives)
            # dependency ordering impacts fingerprint
            # TODO: The following code can be removed after some reasonable time period (added 2014.10.06)
            if existing_package.dependency_set != package_meta['dependencies']
              existing_package.dependency_set = package_meta['dependencies']
              existing_package.save
            end

            if existing_package.release_versions.include? @release_version_model
              if existing_package.blobstore_id.nil?
                packages.each do |package|
                  unless package.blobstore_id.nil?
                    package_meta["blobstore_id"] = package.blobstore_id
                    package_meta["sha1"] = package.sha1
                    break
                  end
                end
              end
              registered_packages << [existing_package, package_meta]
            else
              existing_packages << [existing_package, package_meta]
            end

          else
            # We found a package with the same fingerprint but different
            # (release, name, version) tuple, so we need to make a copy
            # of the package blob and create a new db entry for it

            packages.each do |package|
              unless package.blobstore_id.nil?
                package_meta["blobstore_id"] = package.blobstore_id
                package_meta["sha1"] = package.sha1
                break
              end
            end
            new_packages << package_meta
          end
        end

        package_stemcell_hashes1 = create_packages(new_packages, release_dir)

        package_stemcell_hashes2 = use_existing_packages(existing_packages, release_dir)

        if @compiled_release
          compatible_stemcell_combos = registered_packages.flat_map do |pkg, pkg_meta|
            stemcells_used_by_package(pkg_meta).map do |stemcell|
              {
                  package: pkg,
                  stemcell: stemcell
              }
            end
          end
          consolidated_package_stemcell_hashes = Array(package_stemcell_hashes1) | Array(package_stemcell_hashes2) | compatible_stemcell_combos
          create_compiled_packages(consolidated_package_stemcell_hashes, release_dir)
        else
          backfill_source_for_packages(registered_packages, release_dir)
        end
      end

      # @return [boolean] true if sources were added to at least one package; false if the call had no effect.
      def backfill_source_for_packages(packages, release_dir)
        return false if packages.empty?

        had_effect = false
        single_step_stage("Processing #{packages.size} existing package#{"s" if packages.size > 1}") do
          packages.each do |package, package_meta|
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Adding source for package `#{package_desc}'")
            had_effect |= save_package_source_blob(package, package_meta, release_dir)
            package.save
            @packages[package.name] = package
          end
        end

        had_effect
      end

      # Points release DB model to existing packages described by given metadata
      # @param [Array<Array>] packages Existing packages metadata.
      # @return [Array<Hash>] package & stemcell matching pairs that were registered. empty if no packages were changed.
      def use_existing_packages(packages, release_dir)
        if packages.empty?
          return []
        end

        package_stemcell_hashes = []

        single_step_stage("Processing #{packages.size} existing package#{"s" if packages.size > 1}") do
          packages.each do |package, package_meta|
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Using existing package `#{package_desc}'")
            register_package(package)

            if compiled_release
              stemcells = stemcells_used_by_package(package_meta)
              stemcells.each do |stemcell|
                hash = { package: package, stemcell: stemcell}
                package_stemcell_hashes << hash
              end
            end

            if source_release && package.blobstore_id.nil?
              save_package_source_blob(package, package_meta, release_dir)
              package.save
            end
          end
        end

        return package_stemcell_hashes
      end

      # Creates packages using provided metadata
      # @param [Array<Hash>] packages Packages metadata
      # @param [String] release_dir local path to the unpacked release
      # @return [Array<Hash>, boolean] array of compiled package & stemcell matching pairs that were registered, and a
      def create_packages(package_metas, release_dir)
        if package_metas.empty?
          return []
        end

        package_stemcell_hashes = []

        event_log.begin_stage("Creating new packages", package_metas.size)

        package_metas.each do |package_meta|
          package_desc = "#{package_meta["name"]}/#{package_meta["version"]}"
          package = nil
          event_log.track(package_desc) do
            logger.info("Creating new package `#{package_desc}'")
            package = create_package(package_meta, release_dir)
            register_package(package)
          end

          if @compiled_release
            stemcells = stemcells_used_by_package(package_meta)
            stemcells.each do |stemcell|
              hash = { package: package, stemcell: stemcell}
              package_stemcell_hashes << hash
            end
          end
        end

        return package_stemcell_hashes
      end

      # @return [boolean] true if at least one job was created; false if the call had no effect.
      def create_compiled_packages(all_compiled_packages, release_dir)
        return false if all_compiled_packages.nil?

        event_log.begin_stage('Creating new compiled packages', all_compiled_packages.size)

        had_effect = false
        all_compiled_packages.each do |compiled_package_spec|
          package = compiled_package_spec[:package]
          stemcell = compiled_package_spec[:stemcell]

          existing_compiled_package = Models::CompiledPackage.where(
              :package_id => package.id,
              :stemcell_id => stemcell.id)

          if existing_compiled_package.empty?
            package_desc = "#{package.name}/#{package.version} for #{stemcell.name}/#{stemcell.version}"
            event_log.track(package_desc) do
              create_compiled_package(package, stemcell, release_dir)
              had_effect = true
            end
          end
        end
        had_effect
      end

      def stemcells_used_by_package(package_meta)
        if package_meta['stemcell'].nil?
          raise 'stemcell informatiom(operating system/version) should be listed for each package of a compiled tarball'
        end

        values = package_meta['stemcell'].split('/', 2)
        operating_system = values[0]
        stemcell_version = values[1]
        unless operating_system && stemcell_version
          raise 'stemcell informatiom(operating system/version) should be listed for each package of a compiled tarball'
        end

        stemcells = Models::Stemcell.where(:operating_system => operating_system, :version => stemcell_version)
        if stemcells.empty?
          raise "No stemcells matching OS #{operating_system} version #{stemcell_version}"
        end

        stemcells
      end

      def create_compiled_package(package, stemcell, release_dir)
        tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")
        validate_tgz(tgz, "#{package.name}.tgz")

        compiled_package = Models::CompiledPackage.new

        compiled_package.blobstore_id = BlobUtil.create_blob(tgz)
        compiled_package.sha1 = Digest::SHA1.file(tgz).hexdigest

        transitive_dependencies = @release_version_model.transitive_dependencies(package)
        compiled_package.dependency_key = Models::CompiledPackage.create_dependency_key(transitive_dependencies)

        compiled_package.build = Models::CompiledPackage.generate_build_number(package, stemcell)
        compiled_package.package_id = package.id
        compiled_package.stemcell_id = stemcell.id

        compiled_package.save
      end

      # Creates package in DB according to given metadata
      # @param [Hash] package_meta Package metadata
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def create_package(package_meta, release_dir)
        name, version = package_meta['name'], package_meta['version']

        package_attrs = {
            :release => @release_model,
            :name => name,
            :sha1 => nil,
            :blobstore_id => nil,
            :fingerprint => package_meta['fingerprint'],
            :version => version
        }

        package = Models::Package.new(package_attrs)
        package.dependency_set = package_meta['dependencies']

        save_package_source_blob(package, package_meta, release_dir) unless @compiled_release

        package.save
      end

      # @return [boolean] true if a new blob was created; false otherwise
      def save_package_source_blob(package, package_meta, release_dir)
        return false unless package.blobstore_id.nil?

        name, version, existing_blob = package_meta['name'], package_meta['version'], package_meta['blobstore_id']
        desc = "package '#{name}/#{version}'"

        package.sha1 = package_meta['sha1']

        if existing_blob
          logger.info("Creating #{desc} from existing blob #{existing_blob}")
          package.blobstore_id = BlobUtil.copy_blob(existing_blob)

        elsif package
          logger.info("Creating #{desc} from provided bits")

          package_tgz = File.join(release_dir, 'packages', "#{name}.tgz")
          validate_tgz(package_tgz, desc)
          package.blobstore_id = BlobUtil.create_blob(package_tgz)
        end

        true
      end

      def validate_tgz(tgz, desc)
        result = Bosh::Exec.sh("tar -tzf #{tgz} 2>&1", :on_error => :return)
        if result.failed?
          logger.error("Extracting #{desc} archive failed, tar returned #{result.exit_status}, output: #{result.output}")
          raise PackageInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
        end
      end

      # Marks package model as used by release version model
      # @param [Models::Package] package Package model
      # @return [void]
      def register_package(package)
        @packages[package.name] = package
        @release_version_model.add_package(package)
      end

      # Finds job template definitions in release manifest and sorts them into
      # two buckets: new and existing job templates, then creates new job
      # template records in the database and points release version to existing ones.
      # @param [String] release_dir local path to the unpacked release
      # @return [void]
      def process_jobs(release_dir)
        logger.info("Checking for new jobs in release")

        new_jobs = []
        existing_jobs = []

        @manifest["jobs"].each do |job_meta|
          # Checking whether we might have the same bits somewhere
          @release_version_model.templates.select { |t| t.name == job_meta["name"] }.each do |tmpl|
            if tmpl.fingerprint != job_meta["fingerprint"]
              raise ReleaseExistingJobFingerprintMismatch, "job `#{job_meta["name"]}' had different fingerprint in previously uploaded release `#{@name}/#{@version}'"
            end
          end

          jobs = Models::Template.where(fingerprint: job_meta["fingerprint"]).all

          template = jobs.find do |job|
            job.release_id == @release_model.id &&
            job.name == job_meta["name"] &&
            job.version == job_meta["version"]
          end

          if template.nil?
            new_jobs << job_meta
          else
            existing_jobs << [template, job_meta]
          end
        end

        did_something = create_jobs(new_jobs, release_dir)
        did_something |= use_existing_jobs(existing_jobs)

        did_something
      end

      # @return [boolean] true if at least one job was created; false if the call had no effect.
      def create_jobs(jobs, release_dir)
        return false if jobs.empty?

        event_log.begin_stage("Creating new jobs", jobs.size)
        jobs.each do |job_meta|
          job_desc = "#{job_meta["name"]}/#{job_meta["version"]}"
          event_log.track(job_desc) do
            logger.info("Creating new template `#{job_desc}'")
            template = create_job(job_meta, release_dir)
            register_template(template)
          end
        end

        true
      end

      def create_job(job_meta, release_dir)
        release_job = ReleaseJob.new(job_meta, @release_model, release_dir, @packages, logger)
        release_job.create
      end

      # @param [Array<Array>] jobs Existing jobs metadata
      # @return [boolean] true if at least one job was tied to the release version; false if the call had no effect.
      def use_existing_jobs(jobs)
        return false if jobs.empty?

        single_step_stage("Processing #{jobs.size} existing job#{"s" if jobs.size > 1}") do
          jobs.each do |template, _|
            job_desc = "#{template.name}/#{template.version}"
            logger.info("Using existing job `#{job_desc}'")
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

      # Returns the next release version (to be used for rebased release)
      # @return [String]
      def next_release_version
        attrs = {:release_id => @release_model.id}
        models = Models::ReleaseVersion.filter(attrs).all
        strings = models.map(&:version)
        list = Bosh::Common::Version::ReleaseVersionList.parse(strings)
        list.rebase(@version)
      end
    end
  end
end
