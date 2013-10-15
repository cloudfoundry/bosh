module Bosh::Director
  module Jobs
    class SnapshotSelf < BaseJob
      @queue = :normal

      def self.job_type
        :snapshot_self
      end

      def initialize(options={})
        @cloud = options.fetch(:cloud) { Config.cloud }
        @director_uuid = options.fetch(:director_uuid) { Config.uuid }
        @director_name = options.fetch(:director_name) { Config.name }
        @enable_snapshots = options.fetch(:enable_snapshots) { Config.enable_snapshots }
      end

      def perform
        unless @enable_snapshots
          logger.info('Snapshots are disabled; skipping')
          return
        end

        vm_id = @cloud.current_vm_id
        disks = @cloud.get_disks(vm_id)
        metadata = {
            deployment: 'self',
            job: 'director',
            index: 0,
            director_name: @director_name,
            director_uuid: @director_uuid,
            agent_id: 'self',
            instance_id: vm_id
        }

        disks.each { |disk| @cloud.snapshot_disk(disk, metadata) }

        "Snapshot director disks [#{disks.join(', ')}]"
      rescue Bosh::Clouds::NotImplemented
        logger.info('CPI does not support disk snapshots; skipping')
      end
    end
  end
end
