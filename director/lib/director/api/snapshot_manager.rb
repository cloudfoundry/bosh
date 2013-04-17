module Bosh::Director
  module Api
    class SnapshotManager
      def initialize
        @instance_manager = InstanceManager.new
        @deployment_manager = DeploymentManager.new
        @cloud = Config.cloud
      end

      def snapshot(instance, clean=false)
        instance.persistent_disks.each do |disk|
          cid = @cloud.snapshot_disk(disk.disk_cid)
          snapshot = Models::Snapshot.new(persistent_disk: disk, snapshot_cid: cid, clean: clean)
          snapshot.save
        end
        # return status if one or more snapshots was taken or not?
      end

      def snapshot_instance(deployment, job, index, clean=false)
        instance = @instance_manager.find_by_name(deployment, job, index)
        snapshot(instance, clean)
      end

      def delete_snapshot(id)
        snapshot = Models::Snapshot.find(snapshot_cid: id)
        raise SnapshotNotFound, "snapshot #{id} not found" unless snapshot
        @cloud.delete_snapshot(id)
        snapshot.delete
      end

      def delete_all_snapshots(deployment, job, index)
        instance = @instance_manager.find_by_name(deployment, job, index)
        instance.persistent_disks.each do |disk|
          disk.snapshots.each do |snapshot|
            @cloud.delete_snapshot(snapshot.snapshot_cid)
            snapshot.delete
          end
        end
      end

      def snapshots(deployment_name, job=nil, index=nil)
        deployment = @deployment_manager.find_by_name(deployment_name)

        filter = { deployment: deployment }
        filter[:job] = job if job
        filter[:index] = index if index

        instances = @instance_manager.filter_by(filter)

        result = {}

        instances.each do |instance|
          instance.persistent_disks.each do |disk|
            disk.snapshots.each do |snapshot|
              result[instance.job] ||= {}
              result[instance.job][instance.index] ||= []
              result[instance.job][instance.index] << snapshot.snapshot_cid
            end
          end
        end

        result
      end
    end
  end
end
