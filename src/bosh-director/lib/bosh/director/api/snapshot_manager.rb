module Bosh::Director
  module Api
    class SnapshotManager
      def create_deployment_snapshot_task(username, deployment, options = {})
        JobQueue.new.enqueue(username, Jobs::SnapshotDeployment, 'snapshot deployment', [deployment.name, options], deployment)
      end

      def create_snapshot_task(username, instance, options)
        JobQueue.new.enqueue(username, Jobs::CreateSnapshot, 'create snapshot', [instance.id, options])
      end

      def delete_deployment_snapshots_task(username, deployment)
        JobQueue.new.enqueue(username, Jobs::DeleteDeploymentSnapshots, 'delete deployment snapshots', [deployment.name], deployment)
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

      def snapshots(deployment, job=nil, index_or_id=nil)
        filter = { deployment: deployment }
        filter[:job] = job if job
        if index_or_id
          filter_key = index_or_id.to_s =~ /^\d+$/ ? :index : :uuid
          filter[filter_key] = index_or_id
        end
        result = []
        instances = Models::Instance.filter(filter).all

        instances.each do |instance|
          instance.persistent_disks.each do |disk|
            disk.snapshots.each do |snapshot|
              result << {
                  'job' => instance.job,
                  'index' => instance.index,
                  'uuid' => instance.uuid,
                  'snapshot_cid' => snapshot.snapshot_cid,
                  'created_at' => snapshot.created_at.to_s,
                  'clean' => snapshot.clean
              }
            end
          end
        end

        result
      end

      def self.delete_snapshots(snapshots, options={})
        keep_snapshots_in_the_cloud = options.fetch(:keep_snapshots_in_the_cloud, false)
        snapshots.each do |snapshot|
          unless keep_snapshots_in_the_cloud
            instance = snapshot.persistent_disk.instance
            cloud = CloudFactory.create_with_latest_configs.get_for_az(instance.availability_zone)
            cloud.delete_snapshot(snapshot.snapshot_cid)
          end
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
            agent_id: instance.agent_id,
            instance_id: instance.uuid
        }
        tags = instance.deployment.tags
        metadata.merge!(tags) unless tags.empty?

        cloud = CloudFactory.create_with_latest_configs.get_for_az(instance.availability_zone)
        instance.persistent_disks.each do |disk|
          cid = cloud.snapshot_disk(disk.disk_cid, metadata)
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
