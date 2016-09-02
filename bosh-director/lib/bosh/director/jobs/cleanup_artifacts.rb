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
        @orphan_disk_manager = OrphanDiskManager.new(Config.cloud, Config.logger)
        release_manager = Api::ReleaseManager.new
        @stemcell_manager = Api::StemcellManager.new
        @blobstore = App.instance.blobstores.blobstore
        cloud = Config.cloud
        compiled_package_deleter = Jobs::Helpers::CompiledPackageDeleter.new(@blobstore, logger)
        @stemcell_deleter = Jobs::Helpers::StemcellDeleter.new(cloud, logger)
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
        else
          releases_to_keep, stemcells_to_keep = 2, 2
        end

        unused_release_name_and_version = @releases_to_delete_picker.pick(releases_to_keep)
        release_stage = Config.event_log.begin_stage('Deleting releases', unused_release_name_and_version.count)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          unused_release_name_and_version.each do |name_and_version|
            pool.process do
              name = name_and_version['name']
              version = name_and_version['version']
              release_stage.advance_and_track("#{name}/#{version}") do
                with_release_lock(name, :timeout => 10) do
                  @name_version_release_deleter.find_and_delete_release(name, version, false)
                end
              end
            end
          end
        end

        stemcells_to_delete = @stemcells_to_delete_picker.pick(stemcells_to_keep)
        stemcell_stage = Config.event_log.begin_stage('Deleting stemcells', stemcells_to_delete.count)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          stemcells_to_delete.each do |stemcell|
            pool.process do
              stemcell_stage.advance_and_track("#{stemcell['name']}/#{stemcell['version']}") do
                stemcell_to_delete = @stemcell_manager.find_by_name_and_version(stemcell['name'], stemcell['version'])
                @stemcell_deleter.delete(stemcell_to_delete)
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

        ephemeral_blobs = Models::EphemeralBlob.all
        ephemeral_blob_stage = Config.event_log.begin_stage('Deleting ephemeral blobs', ephemeral_blobs.count)
        ephemeral_blobs.each do |ephemeral_blob|
          ephemeral_blob_stage.advance_and_track("#{ephemeral_blob.blobstore_id}") do
            @blobstore.delete(ephemeral_blob.blobstore_id)
            ephemeral_blob.destroy
          end
        end

        "Deleted #{unused_release_name_and_version.count} release(s), #{stemcells_to_delete.count} stemcell(s), #{orphan_disks.count} orphaned disk(s), #{ephemeral_blobs.count} ephemeral blob(s)"
      end
    end
  end
end
