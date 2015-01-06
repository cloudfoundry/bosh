module Bosh::Director
  module Api
    class SnapshotManager
      def create_deployment_snapshot_task(username, deployment, options = {})
        JobQueue.new.enqueue(username, Jobs::SnapshotDeployment, 'snapshot deployment', [deployment.name, options])
      end

      def create_snapshot_task(username, instance, options)
        JobQueue.new.enqueue(username, Jobs::CreateSnapshot, 'create snapshot', [instance.id, options])
      end

      def delete_deployment_snapshots_task(username, deployment)
        JobQueue.new.enqueue(username, Jobs::DeleteDeploymentSnapshots, 'delete deployment snapshots', [deployment.name])
      end

      def delete_snapshots_task(username, snapshot_cids)
        JobQueue.new.enqueue(username, Jobs::DeleteSnapshots, 'delete snapshot', [snapshot_cids])
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
        unless Config.enable_snapshots
          Config.logger.info('Snapshots are disabled; skipping')
          return []
        end

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

      rescue Bosh::Clouds::NotImplemented
        Config.logger.info('CPI does not support disk snapshots; skipping')
        []
      end
    end
  end
end
