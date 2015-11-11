module Bosh::Director
  module Jobs
    class CleanupArtifacts < BaseJob
      include Bosh::Director::LockHelper

      @queue = :normal

      def self.job_type
        :delete_artifacts
      end

      def self.enqueue(username, config, job_queue)
        job_queue.enqueue(username, Jobs::CleanupArtifacts, 'delete artifacts', [config])
      end

      def initialize(config)
        @config = config
        @disk_manager = DiskManager.new(Config.cloud, Config.logger)
        release_manager = Api::ReleaseManager.new
        @stemcell_manager = Api::StemcellManager.new
        blobstore = App.instance.blobstores.blobstore
        cloud = Config.cloud
        blob_deleter = Jobs::Helpers::BlobDeleter.new(blobstore, logger)
        compiled_package_deleter = Jobs::Helpers::CompiledPackageDeleter.new(blob_deleter, logger)
        @stemcell_deleter = Jobs::Helpers::StemcellDeleter.new(cloud, compiled_package_deleter, logger, event_log)
        @releases_to_delete_picker = Jobs::Helpers::ReleasesToDeletePicker.new(release_manager)
        @stemcells_to_delete_picker = Jobs::Helpers::StemcellsToDeletePicker.new(@stemcell_manager)
        package_deleter = Helpers::PackageDeleter.new(compiled_package_deleter, blob_deleter, logger)
        template_deleter = Helpers::TemplateDeleter.new(blob_deleter, logger)
        release_deleter = Helpers::ReleaseDeleter.new(package_deleter, template_deleter, event_log, logger)
        release_version_deleter =
          Helpers::ReleaseVersionDeleter.new(release_deleter, package_deleter, template_deleter, logger, event_log)
        @name_version_release_deleter =
          Helpers::NameVersionReleaseDeleter.new(release_deleter, release_manager, release_version_deleter, logger)
      end

      def perform
        result = nil

        if @config['remove_all']
          releases_to_keep, stemcells_to_keep = 0, 0
        else
          releases_to_keep, stemcells_to_keep = 2, 2
        end

        unused_release_name_and_version = @releases_to_delete_picker.pick(releases_to_keep)
        release_stage = event_log.begin_stage('Deleting releases', unused_release_name_and_version.count)

        thread_pool = ThreadPool.new(:max_threads => Config.max_threads)
        thread_pool.wrap do |pool|
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

        formatted_releases = if unused_release_name_and_version.empty?
                               'none'
                             else
                               unused_release_name_and_version.map { |nv| "#{nv['name']}/#{nv['version']}" }.join(', ')
                             end
        result = "release(s) deleted: #{formatted_releases}; "

        stemcells_to_delete = @stemcells_to_delete_picker.pick(stemcells_to_keep)

        stemcell_stage = event_log.begin_stage('Deleting stemcells', stemcells_to_delete.count)
        thread_pool = ThreadPool.new(:max_threads => Config.max_threads)
        thread_pool.wrap do |pool|
          stemcells_to_delete.each do |stemcell|
            pool.process do
              stemcell_stage.advance_and_track("#{stemcell['name']}/#{stemcell['version']}") do
                stemcell_to_delete = @stemcell_manager.find_by_name_and_version(stemcell['name'], stemcell['version'])
                @stemcell_deleter.delete(stemcell_to_delete)
              end
            end
          end
        end

        formatted_stemcells = if stemcells_to_delete.empty?
                                'none'
                              else
                                stemcells_to_delete.map { |nv| "#{nv['name']}/#{nv['version']}" }.join(', ')
                              end
        result += "stemcell(s) deleted: #{formatted_stemcells}; "


        if @config['remove_all']
          orphan_disks = Models::OrphanDisk.all
          orphan_disk_stage = event_log.begin_stage('Deleting orphaned disks', orphan_disks.count)

          thread_pool = ThreadPool.new(:max_threads => Config.max_threads)
          thread_pool.wrap do |pool|
            orphan_disks.each do |orphan_disk|
              pool.process do
                orphan_disk_stage.advance_and_track("#{orphan_disk.disk_cid}") do
                  @disk_manager.delete_orphan_disk(orphan_disk)
                end
              end
            end
          end

          formatted_orphan_disk = orphan_disks.empty? ? 'none' : orphan_disks.map(&:disk_cid).join(', ')
          result += "orphaned disk(s) deleted: #{formatted_orphan_disk}"
        end

        result
      end
    end
  end
end
