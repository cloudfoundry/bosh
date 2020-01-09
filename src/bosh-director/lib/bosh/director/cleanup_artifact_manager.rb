module Bosh::Director
  class CleanupArtifactManager
    include LockHelper

    def initialize(options, logger, release_manager: Api::ReleaseManager.new)
      @logger = logger
      @release_manager = release_manager
      @remove_all = options['remove_all']
      @keep_orphaned_disks = options['keep_orphaned_disks']

      dns_blob_age = @remove_all ? 0 : 3600
      dns_blobs_to_keep = if @remove_all && Models::Deployment.count.positive?
                            1
                          elsif @remove_all
                            0
                          else
                            10
                          end

      cleanup_params = { 'max_blob_age' => dns_blob_age, 'num_dns_blobs_to_keep' => dns_blobs_to_keep }
      @dns_blob_cleanup = Jobs::ScheduledDnsBlobsCleanup.new(cleanup_params)

      @stemcell_manager = Api::StemcellManager.new
      @stemcells_to_delete_picker = Jobs::Helpers::StemcellsToDeletePicker.new(@stemcell_manager)
      @stemcell_deleter = Jobs::Helpers::StemcellDeleter.new(logger)

      @blobstore = App.instance.blobstores.blobstore
      @compiled_package_deleter = Jobs::Helpers::CompiledPackageDeleter.new(@blobstore, logger)
      package_deleter = Jobs::Helpers::PackageDeleter.new(@compiled_package_deleter, @blobstore, logger)
      template_deleter = Jobs::Helpers::TemplateDeleter.new(@blobstore, logger)
      release_deleter = Jobs::Helpers::ReleaseDeleter.new(package_deleter, template_deleter, Config.event_log, logger)
      release_version_deleter =
        Jobs::Helpers::ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, Config.event_log)
      @name_version_release_deleter =
        Jobs::Helpers::NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger)

      @orphaned_vm_deleter = OrphanedVMDeleter.new(logger)
      @orphan_disk_manager = OrphanDiskManager.new(Config.logger)
    end

    def show_all
      {
        releases: releases,
        stemcells: stemcells,
        compiled_packages: compiled_packages.map { |r| { package_name: r.package.name, stemcell_os: r.stemcell_os, stemcell_version: r.stemcell_version } },
        orphaned_disks: orphan_disks_list,
        orphaned_vms: Models::OrphanedVm.list_all,
        exported_releases: exported_releases.map(&:blobstore_id),
        dns_blobs: dns_blobs.map { |r| r.blob.blobstore_id },
      }
    end

    def delete
      num_orphaned_vms_deleted = delete_orphaned_vms
      num_releases_deleted = delete_releases
      num_stemcells_deleted = delete_stemcells
      num_compiled_packages_deleted = delete_compiled_packages
      num_orphaned_disks_deleted = delete_orphaned_disks
      num_exported_releases_deleted = delete_exported_releases
      dns_blob_message = delete_expired_dns_blobs

      "Deleted #{num_releases_deleted} release(s), " \
        "#{num_stemcells_deleted} stemcell(s), " \
        "#{num_compiled_packages_deleted} extra compiled package(s), " \
        "#{num_orphaned_disks_deleted} orphaned disk(s), " \
        "#{num_orphaned_vms_deleted} orphaned vm(s), " \
        "#{num_exported_releases_deleted} exported release(s), " \
        "#{dns_blob_message}"
    end

    private

    def orphaned_vms
      Models::OrphanedVm.all
    end

    def releases
      releases_to_keep = @remove_all ? 0 : 2

      releases_to_delete_picker = Jobs::Helpers::ReleasesToDeletePicker.new(@release_manager)
      releases_to_delete_picker.pick(releases_to_keep)
    end

    def compiled_packages
      return [] unless @remove_all

      Jobs::Helpers::CompiledPackagesToDeletePicker.pick(stemcells)
    end

    def stemcells
      @stemcells ||= begin
                       stemcells_to_keep = @remove_all ? 0 : 2
                       @stemcells_to_delete_picker.pick(stemcells_to_keep)
                     end
    end

    def dns_blobs
      @dns_blob_cleanup.blobs_to_delete
    end

    def orphan_disks
      return [] if @keep_orphaned_disks
      return [] unless @remove_all

      Models::OrphanDisk.all
    end

    def orphan_disks_list
      return [] if @keep_orphaned_disks
      return [] unless @remove_all

      @orphan_disk_manager.list_orphan_disks
    end

    def exported_releases
      Models::Blob.where(type: 'exported-release').all
    end

    def delete_orphaned_vms
      orphaned_vm_stage = Config.event_log.begin_stage('Deleting orphaned vms', orphaned_vms.count)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        orphaned_vms.each do |orphaned_vm|
          pool.process do
            orphaned_vm_stage.advance_and_track(orphaned_vm.cid) do
              @orphaned_vm_deleter.delete_vm(orphaned_vm, 10)
            end
          end
        end
      end
      orphaned_vms.count
    end

    def delete_releases
      release_count = releases.map { |r| r['versions'] }.flatten.count
      release_stage = Config.event_log.begin_stage('Deleting releases', release_count)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        releases.each do |release|
          pool.process do
            name = release['name']
            with_release_lock(name, timeout: 10) do
              release['versions'].each do |version|
                release_stage.advance_and_track("#{name}/#{version}") do
                  @name_version_release_deleter.find_and_delete_release(name, version, false)
                end
              end
            end
          end
        end
      end

      release_count
    end

    def delete_stemcells
      count = stemcells.count
      stemcell_stage = Config.event_log.begin_stage('Deleting stemcells', count)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        stemcells.each do |stemcell|
          pool.process do
            stemcell_stage.advance_and_track("#{stemcell['name']}/#{stemcell['version']}") do
              Models::StemcellUpload.where(name: stemcell['name'], version: stemcell['version']).delete
              stemcells = @stemcell_manager.all_by_name_and_version(stemcell['name'], stemcell['version'])
              stemcells.each { |s| @stemcell_deleter.delete(s) }
            end
          end
        end
      end

      count
    end

    def delete_compiled_packages
      remaining_compiled_packages_to_delete = compiled_packages.reject do |cp|
        cp.package.nil? # deleting release version may have already deleted package by cascade
      end
      compiled_package_stage = Config.event_log.begin_stage('Deleting compiled packages',
                                                            remaining_compiled_packages_to_delete.count)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        remaining_compiled_packages_to_delete.each do |compiled_package|
          pool.process do
            cp_desc = "#{compiled_package.name} for #{compiled_package.stemcell_os}/#{compiled_package.stemcell_version}"
            compiled_package_stage.advance_and_track(cp_desc) do
              @compiled_package_deleter.delete(compiled_package)
            end
          end
        end
      end

      remaining_compiled_packages_to_delete.count
    end

    def delete_orphaned_disks
      count = orphan_disks.count
      orphan_disk_stage = Config.event_log.begin_stage('Deleting orphaned disks', count)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        orphan_disks.each do |orphan_disk|
          pool.process do
            orphan_disk_stage.advance_and_track(orphan_disk.disk_cid.to_s) do
              @orphan_disk_manager.delete_orphan_disk(orphan_disk)
            end
          end
        end
      end

      count
    end

    def delete_exported_releases
      exported_release_count = exported_releases.count
      exported_release_stage = Config.event_log.begin_stage('Deleting exported releases', exported_release_count)
      exported_releases.each do |exported_release|
        exported_release_stage.advance_and_track(exported_release.blobstore_id) do
          @blobstore.delete(exported_release.blobstore_id)
          exported_release.destroy
        end
      end

      exported_release_count
    end

    def delete_expired_dns_blobs
      dns_blob_message = ''

      dns_blobs_stage = Config.event_log.begin_stage('Deleting dns blobs', 1)
      dns_blobs_stage.advance_and_track('DNS blobs') do
        dns_blob_message = @dns_blob_cleanup.perform(dns_blobs)
      end

      dns_blob_message
    end
  end
end
