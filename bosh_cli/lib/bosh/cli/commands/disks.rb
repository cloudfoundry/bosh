module Bosh::Cli::Command
  class Disks < Base
    usage 'disks'
    desc 'List all orphaned disks in a deployment (requires --orphaned option)'
    option '--orphaned', 'Return orphaned disks'
    def list
      auth_required
      unless options[:orphaned]
        err("Only 'bosh disks --orphaned' is supported")
      end

      disks = sort(director.list_orphan_disks)
      if disks.empty?
        nl
        say('No orphaned disks')
        nl
        return
      end

      disks_table = table do |table|
        table.headings = 'Disk CID',
          'Size (MiB)',
          'Deployment Name',
          'Instance Name',
          'AZ',
          'Orphaned At'

        disks.each do |disk|
          table << [
            disk['disk_cid'],
            disk['size'] || 'n/a',
            disk['deployment_name'],
            disk['instance_name'],
            disk['az'] || 'n/a',
            disk['orphaned_at']
          ]
        end
      end

      nl
      say(disks_table)
    end

    usage 'attach disk'
    desc 'Attaches an disk to an instance and replaces the current disk'
    def attach(job_name, id, disk_cid)
      auth_required
      manifest = prepare_deployment_manifest
      status, result = director.attach_disk(manifest.name, job_name, id, disk_cid)

      task_report(status, result, "Attached disk #{disk_cid} to #{job_name}/#{id}")
    end

    usage 'delete disk'
    desc 'Deletes an orphaned disk'
    def delete(orphan_disk_cid)
      auth_required

      status, result = director.delete_orphan_disk_by_disk_cid(orphan_disk_cid)

      task_report(status, result, "Deleted orphaned disk #{orphan_disk_cid}")
    end

    private

    def sort(disks)
      disks.sort do |a, b|
        Time.parse(b['orphaned_at']).to_i <=> Time.parse(a['orphaned_at']).to_i
      end
    end
  end
end
