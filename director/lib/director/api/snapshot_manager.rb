module Bosh::Director
  module Api
    class SnapshotManager
      include TaskHelper

      def create_snapshot(user, instance)
        task = create_task(user, :create_snapshot, "create snapshot")
        Resque.enqueue(Jobs::CreateSnapshot, task.id, instance)
        task
      end

      def delete_snapshots(user, snapshots)
        task = create_task(user, :delete_snapshot, "delete snapshot")
        Resque.enqueue(Jobs::DeleteSnapshot, task.id, snapshots)
        task
      end

      def find_by_id(deployment, id)
        snapshot = Models::Snapshot.find(snapshot_cid: id)
        raise SnapshotNotFound, "snapshot #{id} not found" unless snapshot
        unless deployment == snapshot.persistent_disk.instance.deployment
          raise SnapshotNotFound, "snapshot #{id} not found in deployment #{deployment.name}"
        end
        snapshot
      end

      def snapshots(deployment, job=nil, index=nil)
        filter = { deployment: deployment }
        filter[:job] = job if job
        filter[:index] = index if index

        result = {}
        instances = Models::Instance.filter(filter).all

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

      def self.delete_snapshots(snapshots)
        snapshots.each do |snapshot|
          Config.cloud.delete_snapshot(snapshot.snapshot_cid)
          snapshot.delete
        end
      end

      def self.snapshot(instance, options)
        clean = options.fetch(:clean, false)

        instance.persistent_disks.each do |disk|
          cid = Config.cloud.snapshot_disk(disk.disk_cid)
          snapshot = Models::Snapshot.new(persistent_disk: disk, snapshot_cid: cid, clean: clean)
          snapshot.save
        end
      end
    end
  end
end
