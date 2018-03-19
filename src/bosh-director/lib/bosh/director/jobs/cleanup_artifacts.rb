module Bosh::Director
  module Jobs
    class CleanupArtifacts < BaseJob
      include Bosh::Director::LockHelper

      @queue = :normal

      def self.job_type
        :delete_artifacts
      end

      def self.enqueue(username, config, job_queue)
        description = config['remove_all'] ? 'clean up all' : 'clean up'
        job_queue.enqueue(username, Jobs::CleanupArtifacts, description, [config])
      end

      def initialize(config)
        @config = config
        @orphan_disk_manager = OrphanDiskManager.new(Config.logger)
        release_manager = Api::ReleaseManager.new
        @stemcell_manager = Api::StemcellManager.new
        @blobstore = App.instance.blobstores.blobstore
        compiled_package_deleter = Jobs::Helpers::CompiledPackageDeleter.new(@blobstore, logger)
        @stemcell_deleter = Jobs::Helpers::StemcellDeleter.new(logger)
        @releases_to_delete_picker = Jobs::Helpers::ReleasesToDeletePicker.new(release_manager)
        @stemcells_to_delete_picker = Jobs::Helpers::StemcellsToDeletePicker.new(@stemcell_manager)
        package_deleter = Helpers::PackageDeleter.new(compiled_package_deleter, @blobstore, logger)
        template_deleter = Helpers::TemplateDeleter.new(@blobstore, logger)
        release_deleter = Helpers::ReleaseDeleter.new(package_deleter, template_deleter, Config.event_log, logger)
        release_version_deleter =
          Helpers::ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, Config.event_log)
        @name_version_release_deleter =
          Helpers::NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger)
      end

      def perform
        if @config['remove_all']
          releases_to_keep, stemcells_to_keep = 0, 0
          dns_blob_age, dns_blobs_to_keep = 0, 0

          if Models::Deployment.count > 0
            dns_blobs_to_keep = 1
          end
        else
          releases_to_keep, stemcells_to_keep = 2, 2
          dns_blob_age, dns_blobs_to_keep = 3600, 10
        end

        unused_release_name_and_versions = @releases_to_delete_picker.pick(releases_to_keep)
        release_count = unused_release_name_and_versions.map{|r| r['versions']}.flatten.count
        release_stage = Config.event_log.begin_stage('Deleting releases', release_count)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          unused_release_name_and_versions.each do |release|
            pool.process do
              name = release['name']
              with_release_lock(name, :timeout => 10) do
                release['versions'].each do |version|
                  release_stage.advance_and_track("#{name}/#{version}") do
                    @name_version_release_deleter.find_and_delete_release(name, version, false)
                  end
                end
              end
            end
          end
        end

        stemcells_to_delete = @stemcells_to_delete_picker.pick(stemcells_to_keep)
        stemcell_stage = Config.event_log.begin_stage('Deleting stemcells', stemcells_to_delete.count)
        ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
          stemcells_to_delete.each do |stemcell|
            pool.process do
              stemcell_stage.advance_and_track("#{stemcell['name']}/#{stemcell['version']}") do
                Models::StemcellUpload.where(name: stemcell['name'], version: stemcell['version']).delete
                stemcells = @stemcell_manager.all_by_name_and_version(stemcell['name'], stemcell['version'])
                stemcells.each { |s| @stemcell_deleter.delete(s) }
              end
            end
          end
        end

        orphan_disks = []
        if @config['remove_all']
          orphan_disks = Models::OrphanDisk.all
          orphan_disk_stage = Config.event_log.begin_stage('Deleting orphaned disks', orphan_disks.count)
          ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
            orphan_disks.each do |orphan_disk|
              pool.process do
                orphan_disk_stage.advance_and_track("#{orphan_disk.disk_cid}") do
                  @orphan_disk_manager.delete_orphan_disk(orphan_disk)
                end
              end
            end
          end
        end

        exported_releases = Models::Blob.where(type: 'exported-release')
        exported_releases_count = exported_releases.count
        exported_release_stage = Config.event_log.begin_stage('Deleting exported releases', exported_releases.count)
        exported_releases.each do |exported_release|
          exported_release_stage.advance_and_track("#{exported_release.blobstore_id}") do
            @blobstore.delete(exported_release.blobstore_id)
            exported_release.destroy
          end
        end

        dns_blob_message = ''
        dns_blobs_stage = Config.event_log.begin_stage('Deleting dns blobs', 1)
        dns_blobs_stage.advance_and_track('DNS blobs') do
          cleanup_params = {'max_blob_age' => dns_blob_age, 'num_dns_blobs_to_keep' => dns_blobs_to_keep}
          dns_blob_message = ScheduledDnsBlobsCleanup.new(cleanup_params).perform
        end

        "Deleted #{release_count} release(s), #{stemcells_to_delete.count} stemcell(s), #{orphan_disks.count} orphaned disk(s), #{exported_releases_count} exported release(s)\n#{dns_blob_message}"
      end
    end
  end
end
