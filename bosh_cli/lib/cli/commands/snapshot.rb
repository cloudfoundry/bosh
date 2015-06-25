# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Cli::Command
  class Snapshot < Base
    usage 'snapshots'
    desc 'List all snapshots'
    def list(job = nil, index = nil)
      auth_required

      deployment_name = prepare_deployment_manifest(show_state: true).name

      snapshots = director.list_snapshots(deployment_name, job, index)

      sorted = snapshots.sort do |a, b|
        s = a['job'].to_s <=> b['job'].to_s
        s = a['index'].to_i <=> b['index'].to_i if s == 0
        s = a['created_at'].to_s <=> b['created_at'].to_s if s == 0
        s
      end

      snapshots_table = table do |t|
        t.headings = ['Job/index', 'Snapshot CID', 'Created at', 'Clean']

        sorted.each do |snapshot|
          job = "#{snapshot['job'] || 'unknown'}/#{snapshot['index'] || 'unknown'}"
          t << [job, snapshot['snapshot_cid'], snapshot['created_at'], snapshot['clean']]
        end
      end

      nl
      say(snapshots_table)
      nl
      say('Snapshots total: %d' % snapshots.size)
    end

    usage 'take snapshot'
    desc 'Takes a snapshot'
    def take(job = nil, index = nil)
      auth_required

      deployment_name = prepare_deployment_manifest(show_state: true).name

      unless job && index
        unless confirmed?("Are you sure you want to take a snapshot of all deployment `#{deployment_name}'?")
          say('Canceled taking snapshot'.make_green)
          return
        end
      end

      status, task_id = director.take_snapshot(deployment_name, job, index)

      task_report(status, task_id, 'Snapshot taken')
    end

    usage 'delete snapshot'
    desc 'Deletes a snapshot'
    def delete(snapshot_cid)
      auth_required

      deployment_name = prepare_deployment_manifest(show_state: true).name

      unless confirmed?("Are you sure you want to delete snapshot `#{snapshot_cid}'?")
        say('Canceled deleting snapshot'.make_green)
        return
      end

      status, task_id = director.delete_snapshot(deployment_name, snapshot_cid)

      task_report(status, task_id, "Deleted Snapshot `#{snapshot_cid}'")
    end

    usage 'delete snapshots'
    desc 'Deletes all snapshots of a deployment'
    def delete_all
      auth_required

      deployment_name = prepare_deployment_manifest(show_state: true).name

      unless confirmed?("Are you sure you want to delete all snapshots of deployment `#{deployment_name}'?")
        say('Canceled deleting snapshots'.make_green)
        return
      end

      status, task_id = director.delete_all_snapshots(deployment_name)

      task_report(status, task_id, "Deleted all snapshots of deployment `#{deployment_name}'")
    end
  end
end
