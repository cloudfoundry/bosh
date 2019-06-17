module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      class PackagePersister < BaseJob
        def initialize(
          new_packages,
          existing_packages,
          registered_packages,
          compiled_release,
          release_dir,
          fix,
          manifest,
          release_version_model,
          release_model
        )
          @compiled_release = compiled_release
          @new_packages = new_packages
          @existing_packages = existing_packages
          @release_dir = release_dir
          @registered_packages = registered_packages
          @fix = fix
          @manifest = manifest
          @release_version_model = release_version_model
          @release_model = release_model
        end

        def self.persist(*args)
          new(*args).persist
        end

        attr_reader :new_packages, :existing_packages, :registered_packages, :release_dir, :compiled_release

        # Creates package in DB according to given metadata
        # @param [Hash] package_meta Package metadata
        # @param [String] release_dir local path to the unpacked release
        # @return [void]
        def self.create_package(logger, release_model, fix, compiled_release, package_meta, release_dir)
          name = package_meta['name']
          version = package_meta['version']

          package_attrs = {
            release: release_model,
            name: name,
            sha1: nil,
            blobstore_id: nil,
            fingerprint: package_meta['fingerprint'],
            version: version,
          }

          package = Models::Package.new(package_attrs)
          package.dependency_set = package_meta['dependencies']

          save_package_source_blob(logger, package, fix, package_meta, release_dir) unless compiled_release

          package.save
        end

        # @return [boolean] true if a new blob was created; false otherwise
        def self.save_package_source_blob(logger, package, fix, package_meta, release_dir)
          name = package_meta['name']
          version = package_meta['version']
          existing_blob = package_meta['blobstore_id']
          sha1 = package_meta['sha1']
          desc = "package '#{name}/#{version}'"
          package_tgz = File.join(release_dir, 'packages', "#{name}.tgz")

          if fix
            package.sha1 = sha1

            unless package.blobstore_id.nil?
              delete_compiled_packages(logger, package)
              validate_tgz(logger, package_tgz, desc)
              fix_package(logger, package, package_tgz)
              return true
            end

            if existing_blob
              pkg = Models::Package.where(blobstore_id: existing_blob).first
              delete_compiled_packages(logger, package)
              fix_package(logger, pkg, package_tgz)
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
          validate_tgz(logger, package_tgz, desc)
          package.blobstore_id = BlobUtil.create_blob(package_tgz)

          true
        end

        def self.validate_tgz(logger, tgz, desc)
          result = Bosh::Exec.sh("tar -tzf #{tgz} 2>&1", on_error: :return)
          if result.failed?
            logger.error("Extracting #{desc} archive failed, tar returned #{result.exit_status}, output: #{result.output}")
            raise PackageInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
          end
        end

        def self.fix_package(logger, package, package_tgz)
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

        def self.delete_compiled_packages(logger, package)
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

        def persist
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

        private

        def source_release
          !compiled_release
        end

        # @return [boolean] true if sources were added to at least one package; false if the call had no effect.
        def backfill_source_for_packages(packages, release_dir)
          return false if packages.empty?

          had_effect = false
          single_step_stage("Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
            packages.each do |package, package_meta|
              package_desc = "#{package.name}/#{package.version}"
              logger.info("Adding source for package '#{package_desc}'")
              had_effect |= self.class.save_package_source_blob(logger, package, @fix, package_meta, release_dir)
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
                self.class.save_package_source_blob(logger, package, @fix, package_meta, release_dir)
                package.save
              end
            end
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
              package = self.class.create_package(logger, @release_model, @fix, @compiled_release, package_meta, release_dir)
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

        def compiled_packages_matching(package, stemcell)
          other_compiled_packages = []
          dependency_key = dependency_key(package)
          packages = Models::Package.where(fingerprint: package.fingerprint).order_by(:id).all
          packages.each do |pkg|
            other_compiled_packages.concat(find_compiled_packages(pkg.id, stemcell[:os], stemcell[:version], dependency_key).all)
          end
          other_compiled_packages
        end

        def find_compiled_packages(pkg_id, stemcell_os, stemcell_version, dependency_key)
          Models::CompiledPackage.where(
            package_id: pkg_id,
            stemcell_os: stemcell_os,
            stemcell_version: stemcell_version,
            dependency_key: dependency_key,
          )
        end

        def create_compiled_package(package, package_sha1, stemcell_os, stemcell_version, release_dir, other_compiled_package)
          if other_compiled_package.nil?
            tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")
            self.class.validate_tgz(logger, tgz, "#{package.name}.tgz")
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

        # Marks package model as used by release version model
        # @param [Models::Package] package Package model
        # @return [void]
        def register_package(package)
          @release_version_model.add_package(package)
        end

        def dependency_key(package)
          KeyGenerator.new.dependency_key_from_models(package, @release_version_model)
        end
      end
    end
  end
end
