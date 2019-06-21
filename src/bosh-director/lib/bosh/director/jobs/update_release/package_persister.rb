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
            created_package_refs = create_packages(logger, release_model, release_version_model, fix, compiled_release, new_packages, release_dir)

            existing_package_refs = use_existing_packages(logger, compiled_release, release_version_model, fix, existing_packages, release_dir)

            if compiled_release
              registered_package_refs = registered_packages.map do |pkg, pkg_meta|
                {
                  package: pkg,
                  package_meta: pkg_meta,
                }
              end

              all_package_refs = Array(created_package_refs) | Array(existing_package_refs) | registered_package_refs
              create_compiled_packages(logger, manifest, release_version_model, fix, all_package_refs, release_dir)
              return
            end

            backfill_source_for_packages(logger, fix, registered_packages, release_dir)
          end

          # Creates package in DB according to given metadata
          # @param [Logging::Logger] logger a logger that responds to info
          # @param [Boolean] fix whether this package is being uploaded with --fix
          # @param [Boolean] compiled_release true if this is a compiled_release
          # @param [Hash] package_meta Package metadata
          # @param [String] release_dir local path to the unpacked release
          # @return [void]
          def create_package(
            logger:,
            release_model:,
            fix:,
            compiled_release:,
            package_meta:,
            release_dir:
          )
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

          def validate_tgz(logger, tgz, desc)
            result = Bosh::Exec.sh("tar -tzf #{tgz} 2>&1", on_error: :return)
            if result.failed?
              logger.error("Extracting #{desc} archive failed, tar returned #{result.exit_status}, output: #{result.output}")
              raise PackageInvalidArchive, "Extracting #{desc} archive failed. Check task debug log for details."
            end
          end

          def save_package_source_blob(logger, package, fix, package_meta, release_dir)
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

          def fix_package(logger, package, package_tgz)
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

          def delete_compiled_packages(logger, package)
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

          def backfill_source_for_packages(logger, fix, packages, release_dir)
            return false if packages.empty?

            had_effect = false
            single_step_stage(logger, "Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
              packages.each do |package, package_meta|
                package_desc = "#{package.name}/#{package.version}"
                logger.info("Adding source for package '#{package_desc}'")
                had_effect |= save_package_source_blob(logger, package, fix, package_meta, release_dir)
                package.save
              end
            end

            had_effect
          end

          def use_existing_packages(logger, compiled_release, release_version_model, fix, packages, release_dir)
            return [] if packages.empty?

            package_refs = []

            single_step_stage(logger, "Processing #{packages.size} existing package#{'s' if packages.size > 1}") do
              packages.each do |package, package_meta|
                package_desc = "#{package.name}/#{package.version}"
                logger.info("Using existing package '#{package_desc}'")
                register_package(release_version_model, package)

                if compiled_release
                  package_refs << {
                    package: package,
                    package_meta: package_meta,
                  }
                end

                if !compiled_release && (package.blobstore_id.nil? || fix)
                  save_package_source_blob(logger, package, fix, package_meta, release_dir)
                  package.save
                end
              end
            end

            package_refs
          end

          def create_compiled_packages(logger, manifest, release_version_model, fix, all_compiled_packages, release_dir)
            return false if all_compiled_packages.nil?

            event_log_stage = Config.event_log.begin_stage('Creating new compiled packages', all_compiled_packages.size)
            had_effect = false

            all_compiled_packages.each do |compiled_package_spec|
              package = compiled_package_spec[:package]
              stemcell = Models::CompiledPackage.split_stemcell_os_and_version(compiled_package_spec[:package_meta]['stemcell'])
              compiled_pkg_tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")

              stemcell_os = stemcell[:os]
              stemcell_version = stemcell[:version]

              existing_compiled_packages = find_compiled_packages(package.id, stemcell_os, stemcell_version, dependency_key(release_version_model, package))

              if existing_compiled_packages.empty?
                package_desc = "#{package.name}/#{package.version} for #{stemcell_os}/#{stemcell_version}"
                event_log_stage.advance_and_track(package_desc) do
                  other_compiled_packages = compiled_packages_matching(release_version_model, package, stemcell)
                  if fix
                    other_compiled_packages.each do |other_compiled_package|
                      fix_compiled_package(logger, other_compiled_package, compiled_pkg_tgz)
                    end
                  end
                  package_sha1 = compiled_package_spec[:package_meta]['compiled_package_sha1']
                  create_compiled_package(logger, release_version_model, manifest, package, package_sha1, stemcell_os, stemcell_version, release_dir, other_compiled_packages.first)
                  had_effect = true
                end
              elsif fix
                existing_compiled_package = existing_compiled_packages.first
                fix_compiled_package(logger, existing_compiled_package, compiled_pkg_tgz)
              end
            end

            had_effect
          end

          def fix_compiled_package(logger, compiled_pkg, compiled_pkg_tgz)
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
                register_package(release_version_model, package)
              end

              next unless compiled_release

              package_refs << {
                package: package,
                package_meta: package_meta,
              }
            end

            package_refs
          end

          def compiled_packages_matching(release_version_model, package, stemcell)
            other_compiled_packages = []
            dependency_key = dependency_key(release_version_model, package)
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

          def create_compiled_package(logger, release_version_model, manifest, package, package_sha1, stemcell_os, stemcell_version, release_dir, other_compiled_package)
            if other_compiled_package.nil?
              tgz = File.join(release_dir, 'compiled_packages', "#{package.name}.tgz")
              validate_tgz(logger, tgz, "#{package.name}.tgz")
                           blobstore_id = BlobUtil.create_blob(tgz)
                           sha1 = package_sha1
            else
              blobstore_id = BlobUtil.copy_blob(other_compiled_package.blobstore_id)
              sha1 = other_compiled_package.sha1
            end

            compiled_package = Models::CompiledPackage.new
            compiled_package.blobstore_id = blobstore_id
            compiled_package.sha1 = sha1
            release_version_model_dependency_key = dependency_key(release_version_model, package)
            if release_version_model_dependency_key != CompiledRelease::Manifest.new(manifest).dependency_key(package.name)
              raise ReleasePackageDependencyKeyMismatch, "The uploaded release contains package dependencies in '#{package.name}' that do not match database records."
            end

            compiled_package.dependency_key = release_version_model_dependency_key

            compiled_package.build = Models::CompiledPackage.generate_build_number(package, stemcell_os, stemcell_version)
            compiled_package.package_id = package.id

            compiled_package.stemcell_os = stemcell_os
            compiled_package.stemcell_version = stemcell_version

            compiled_package.save
          end

          def register_package(release_version_model, package)
            release_version_model.add_package(package)
          end

          def dependency_key(release_version_model, package)
            KeyGenerator.new.dependency_key_from_models(package, release_version_model)
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
