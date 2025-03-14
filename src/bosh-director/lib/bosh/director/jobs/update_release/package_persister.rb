module Bosh::Director
  module Jobs
    class UpdateRelease < BaseJob
      class PackagePersister
        class << self
          def persist(
            new_packages:,
            existing_packages:,
            registered_packages:,
            compiled_release:,
            release_dir:,
            fix:,
            manifest:,
            release_version_model:,
            release_model:
          )
            logger = Config.logger
            created_compiled_package_refs = create_packages(
              logger,
              release_model,
              release_version_model,
              fix,
              compiled_release,
              new_packages,
              release_dir,
            )

            existing_compiled_package_refs = use_existing_packages(
              logger,
              compiled_release,
              release_version_model,
              fix,
              existing_packages,
              release_dir,
            )

            if compiled_release
              registered_compiled_package_refs = registered_packages.map do |pkg, pkg_meta|
                {
                  package: pkg,
                  package_meta: pkg_meta,
                }
              end

              all_package_refs = created_compiled_package_refs | existing_compiled_package_refs | registered_compiled_package_refs
              create_compiled_packages(logger, manifest, release_version_model, fix, all_package_refs, release_dir)
              return
            end

            backfill_source_for_packages(logger, fix, registered_packages, release_dir)
          end

          # Note: This is public for testing purposes.
          # Creates package in DB according to given metadata
          # @param [Logging::Logger] logger a logger that responds to info
          # @param [Boolean] fix whether this package is being uploaded with --fix
          # @param [Boolean] compiled_release true if this is a compiled_release
          # @param [Hash] package_meta Package metadata
          # @param [String] release_dir local path to the unpacked release
          # @return [void]
          def create_package(logger:, release_model:, fix:, compiled_release:, package_meta:, release_dir:)
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

          private

          def create_packages(logger, release_model, release_version_model, fix, compiled_release, package_metas, release_dir)
            return [] if package_metas.empty?

            package_refs = []

            event_log_stage = Config.event_log.begin_stage('Creating new packages', package_metas.size)

            package_metas.each do |package_meta|
              package_desc = "#{package_meta['name']}/#{package_meta['version']}"
              package = nil
              event_log_stage.advance_and_track(package_desc) do
                logger.info("Creating new package '#{package_desc}'")
                package = create_package(
                  logger:           logger,
                  release_model:    release_model,
                  fix:              fix,
                  compiled_release: compiled_release,
                  package_meta:     package_meta,
                  release_dir:      release_dir,
                )
                release_version_model.add_package(package)
              end

              next unless compiled_release

              package_refs << {
                package: package,
                package_meta: package_meta,
              }
            end

            package_refs
          end

          def save_package_source_blob(logger, package, fix, package_meta, release_dir)
            name          = package_meta['name']
            version       = package_meta['version']
            existing_blob = package_meta['blobstore_id']
            sha1          = package_meta['sha1']
            desc          = "package '#{name}/#{version}'"
            package_tgz   = File.join(release_dir, 'packages', "#{name}.tgz")

            return create_or_fix_package(logger, sha1, package, package_tgz, desc, existing_blob) if fix

            create_or_update_blob(logger, sha1, package, package_tgz, desc, existing_blob)
          end

          def create_or_fix_package(logger, sha1, package, package_tgz, desc, existing_blob)
            package.sha1 = sha1
            unless package.blobstore_id.nil?
              delete_compiled_packages(logger, package)
              fix_package(logger, 'package', package, package_tgz, sha1)
              return true
            end

            if existing_blob
              existing_package_model = Models::Package.where(blobstore_id: existing_blob).first
              delete_compiled_packages(logger, package)
              fix_package(logger, 'package', existing_package_model, package_tgz, sha1)
              package.blobstore_id = BlobUtil.copy_blob(existing_package_model.blobstore_id)
              return true
            end

            create_package_from_bits(logger, package, package_tgz, sha1, desc)
            true
          end

          def create_or_update_blob(logger, sha1, package, package_tgz, desc, existing_blob)
            return false unless package.blobstore_id.nil?

            if existing_blob
              package.sha1 = sha1
              logger.info("Creating #{desc} from existing blob #{existing_blob}")
              package.blobstore_id = BlobUtil.copy_blob(existing_blob)

              return true
            end

            logger.info("Creating #{desc} from provided bits")
            create_package_from_bits(logger, package, package_tgz, sha1, desc)
            true
          end

          def create_package_from_bits(logger, package, package_tgz, sha1, desc)
            validate_tgz(logger, package_tgz, desc)
            package.sha1 = sha1
            package.blobstore_id = BlobUtil.create_blob(package_tgz)
          end

          def fix_package(logger, desc, package, package_tgz, sha1)
            delete_package_blob(logger, desc, package)
            create_package_from_bits(logger, package, package_tgz, sha1, desc)
            logger.info("Re-created package '#{package.name}/#{package.version}' \
                        with blobstore_id '#{package.blobstore_id}'")
            package.save
          end

          def delete_package_blob(logger, desc, package)
            logger.info("Deleting #{desc} '#{package.name}/#{package.version}'")
            BlobUtil.delete_blob(package.blobstore_id)
          rescue Bosh::Director::Blobstore::BlobstoreError => e
            logger.info("Error deleting #{desc} '#{package.blobstore_id}, #{package.name}/#{package.version}': #{e.inspect}")
          end

          def validate_tgz(logger, tgz, desc)
            result = Bosh::Common::Exec.sh("tar -tzf #{tgz} 2>&1", on_error: :return)
            if result.failed?
              logger.error("Extracting #{desc} archive failed, tar returned #{result.exit_status}, output: #{result.output}")
              raise PackageInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
            end
          end

          def delete_compiled_packages(logger, package)
            package.compiled_packages.each do |compiled_pkg|
              logger.info("Deleting compiled package '#{compiled_pkg.name}' for \
                          '#{compiled_pkg.stemcell_os}/#{compiled_pkg.stemcell_version}' \
                          with blobstore_id '#{compiled_pkg.blobstore_id}'")

              delete_package_blob(logger, 'compiled package', compiled_pkg)
              compiled_pkg.destroy
            end
          end

          def use_existing_packages(logger, compiled_release, release_version_model, fix, packages, release_dir)
            return [] if packages.empty?

            package_refs = []

            single_step_stage(logger, "Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
              packages.each do |package, package_meta|
                use_existing_package(logger, release_version_model, compiled_release, package, fix, package_meta, release_dir)
                package_refs << { package: package, package_meta: package_meta } if compiled_release
              end
            end

            package_refs
          end

          def use_existing_package(logger, release_version_model, compiled_release, package, fix, package_meta, release_dir)
            package_desc = "#{package.name}/#{package.version}"
            logger.info("Using existing package '#{package_desc}'")
            release_version_model.add_package(package)

            return if compiled_release

            save_package_source_blob(logger, package, fix, package_meta, release_dir)
            package.save
          end

          def create_compiled_packages(logger, manifest, release_version_model, fix, all_compiled_packages, release_dir)
            return false if all_compiled_packages.nil?

            event_log_stage = Config.event_log.begin_stage('Creating new compiled packages', all_compiled_packages.size)

            all_compiled_packages.each do |compiled_package_spec|
              create_compiled_package(logger, compiled_package_spec, release_dir, release_version_model, event_log_stage, fix, manifest)
            end
          end

          def create_compiled_package(logger, compiled_package_spec, release_dir, release_version_model, event_log_stage, fix, manifest)
            package = compiled_package_spec[:package]
            stemcell = Models::CompiledPackage.split_stemcell_os_and_version(compiled_package_spec[:package_meta]['stemcell'])
            compiled_pkg_tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")

            stemcell_os = stemcell[:os]
            stemcell_version = stemcell[:version]
            release_version_model_dependency_key = dependency_key(release_version_model, package, manifest)

            existing_compiled_packages = find_compiled_packages(package.id, stemcell_os, stemcell_version, release_version_model_dependency_key)
            compiled_package_sha1 = compiled_package_spec[:package_meta]['compiled_package_sha1']

            if existing_compiled_packages.empty?
              use_similar_packages(
                logger,
                package,
                stemcell_os,
                stemcell_version,
                event_log_stage,
                release_version_model,
                stemcell,
                fix,
                compiled_package_spec,
                manifest,
                release_dir,
                compiled_pkg_tgz,
                release_version_model_dependency_key,
                compiled_package_sha1,
              )
            elsif fix
              fix_package(logger, 'compiled package', existing_compiled_packages.first, compiled_pkg_tgz, compiled_package_sha1)
            end
          end

          def use_similar_packages(logger, package, stemcell_os, stemcell_version, event_log_stage, release_version_model, stemcell, fix, compiled_package_spec, manifest, release_dir, compiled_pkg_tgz, dependency_key, compiled_package_sha1)
            event_log_stage.advance_and_track("#{package.name}/#{package.version} for #{stemcell_os}/#{stemcell_version}") do
              similar_package = fix_similar_packages(logger, package, fix, stemcell, dependency_key, compiled_package_sha1, compiled_pkg_tgz)

              compiled_package = Models::CompiledPackage.new(
                sha1: similar_package&.sha1 || compiled_package_sha1,
                dependency_key: dependency_key,
                package_id: package.id,
                stemcell_os: stemcell_os,
                stemcell_version: stemcell_version,
                build: Models::CompiledPackage.generate_build_number(package, stemcell_os, stemcell_version),
              )

              create_or_update_blob(
                logger,
                compiled_package.sha1,
                compiled_package,
                File.join(release_dir, 'compiled_packages', "#{package.name}.tgz"),
                'compiled package',
                similar_package&.blobstore_id,
              )

              compiled_package.save
            end
          end

          def fix_similar_packages(logger, package, fix, stemcell, dependency_key, compiled_package_sha1, compiled_pkg_tgz)
            other_compiled_packages = []
            packages = Models::Package.where(name: package.name, fingerprint: package.fingerprint).order_by(:id).all
            packages.each do |pkg|
              other_packages = find_compiled_packages(pkg.id, stemcell[:os], stemcell[:version], dependency_key).all
              other_packages.each do |other_compiled_package|
                fix_package(logger, 'compiled package', other_compiled_package, compiled_pkg_tgz, compiled_package_sha1) if fix
              end
              other_compiled_packages.concat(other_packages)
            end

            other_compiled_packages.first
          end

          def backfill_source_for_packages(logger, fix, packages, release_dir)
            return false if packages.empty?

            single_step_stage(logger, "Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
              packages.each do |package, package_meta|
                package_desc = "#{package.name}/#{package.version}"
                logger.info("Adding source for package '#{package_desc}'")
                save_package_source_blob(logger, package, fix, package_meta, release_dir)
                package.save
              end
            end
          end

          def find_compiled_packages(pkg_id, stemcell_os, stemcell_version, dependency_key)
            Models::CompiledPackage.where(
              package_id: pkg_id,
              stemcell_os: stemcell_os,
              stemcell_version: stemcell_version,
              dependency_key: dependency_key,
            )
          end

          def dependency_key(release_version_model, package, manifest)
            release_version_model_dependency_key = KeyGenerator.new.dependency_key_from_models(package, release_version_model)

            if release_version_model_dependency_key != CompiledRelease::Manifest.new(manifest).dependency_key(package.name)
              raise ReleasePackageDependencyKeyMismatch, "The uploaded release contains package dependencies in '#{package.name}' that do not match database records."
            end

            release_version_model_dependency_key
          end

          def begin_stage(logger, stage_name, n_steps)
            event_log_stage = Config.event_log.begin_stage(stage_name, n_steps)
            logger.info(stage_name)
            event_log_stage
          end

          def track_and_log(event_log_stage, logger, task, log = true)
            event_log_stage.advance_and_track(task) do |ticker|
              logger.info(task) if log
              yield ticker if block_given?
            end
          end

          def single_step_stage(logger, stage_name)
            event_log_stage = begin_stage(logger, stage_name, 1)
            track_and_log(event_log_stage, logger, stage_name, false) { yield }
          end
        end
      end
    end
  end
end
