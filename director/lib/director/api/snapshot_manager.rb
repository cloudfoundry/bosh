module Bosh::Director
  module Api
    class SnapshotManager
      include TaskHelper

      def create_deployment_snapshot_task(user, deployment, options = {})
        task = create_task(user, :snapshot_deployment, "snapshot deployment")
        Resque.enqueue(Jobs::SnapshotDeployment, task.id, deployment.name, options)
        task
      end

      def create_snapshot_task(user, instance, options)
        task = create_task(user, :create_snapshot, "create snapshot")
        Resque.enqueue(Jobs::CreateSnapshot, task.id, instance.id, options)
        task
      end

      def delete_deployment_snapshots_task(user, deployment)
        task = create_task(user, :delete_deployment_napshots, "delete deployment snapshots")
        Resque.enqueue(Jobs::DeleteDeploymentSnapshots, task.id, deployment.name)
        task
      end

      def delete_snapshots_task(user, snapshot_cids)
        task = create_task(user, :delete_snapshot, "delete snapshot")
        Resque.enqueue(Jobs::DeleteSnapshots, task.id, snapshot_cids)
        task
      end

      def find_by_cid(deployment, snapshot_cid)
        snapshot = Models::Snapshot.find(snapshot_cid: snapshot_cid)
        raise SnapshotNotFound, "snapshot #{snapshot_cid} not found" unless snapshot
        unless deployment == snapshot.persistent_disk.instance.deployment
          raise SnapshotNotFound, "snapshot #{snapshot_cid} not found in deployment #{deployment.name}"
        end
        snapshot
      end

      def snapshots(deployment, job=nil, index=nil)
        filter = { deployment: deployment }
        filter[:job] = job if job
        filter[:index] = index if index

        result = []
        instances = Models::Instance.filter(filter).all

        instances.each do |instance|
          instance.persistent_disks.each do |disk|
            disk.snapshots.each do |snapshot|
              result << {
                  'job' => instance.job,
                  'index' => instance.index,
                  'snapshot_cid' => snapshot.snapshot_cid,
                  'created_at' => snapshot.created_at.to_s,
                  'clean' => snapshot.clean
              }
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

      def self.take_snapshot(instance, options={})
        clean = options.fetch(:clean, false)
        snapshot_cids = []
        metadata = {
            deployment: instance.deployment.name,
            job: instance.job,
            index: instance.index,
            director_name: Config.name,
            director_uuid: Config.uuid,
            agent_id: instance.vm.agent_id,
            instance_id: instance.vm_id
        }

        instance.persistent_disks.each do |disk|
          cid = Config.cloud.snapshot_disk(disk.disk_cid, metadata)
          snapshot = Models::Snapshot.new(persistent_disk: disk, snapshot_cid: cid, clean: clean)
          snapshot.save
          snapshot_cids << snapshot.snapshot_cid
        end

        snapshot_cids
      end
    end
  end
end
