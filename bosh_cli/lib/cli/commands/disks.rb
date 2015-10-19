module Bosh::Cli::Command
  class Disks < Base
    usage 'disks'
    desc 'List all orphaned disks in a deployment (requires --orphan option)'
    option '--orphaned', 'Return orphaned disks'

    def list
      auth_required
      unless options[:orphaned]
        err('Only `bosh disks --orphan` is supported')
      end

      disks = sort(director.list_orphan_disks)
      disks_table = table do |table|
        table.headings = 'Disk CID',
          'Deployment Name',
          'Instance Name',
          'Disk Size',
          'Availability Zone',
          'Cloud Properties',
          'Orphaned At'

        disks.each do |disk|
          table << [
            disk['disk_cid'],
            disk['deployment_name'],
            disk['instance_name'],
            disk['size'],
            disk['availability_zone'],
            disk['cloud_properties'],
            disk['orphaned_at']
          ]
        end
      end

      nl
      say(disks_table)

    end

    usage 'delete disk'
    desc 'Deletes an orphaned disk'
    def delete(orphan_disk_cid)
      auth_required

      status, result = director.delete_orphan_disk(orphan_disk_cid)

      task_report(status, result, "Deleted orphan disk #{orphan_disk_cid}")
    end

    private

    def sort(disks)
      puts disks.pretty_inspect
      disks.sort do |a, b|
        a['instance_name'].to_s <=> b['instance_name'].to_s
      end
    end
  end
end
