module Bosh::Cli::Command
  class Disks < Base
    usage 'disks'
    desc 'List all orphaned disks in a deployment (requires --orphan option)'
    option '--orphaned', 'Return orphaned disks'

    def list
      unless options[:orphaned]
        err("Only `bosh disks --orphan` is supported")
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

    private

    def sort(disks)
      puts disks.pretty_inspect
      disks.sort do |a, b|
        a['instance_name'].to_s <=> b['instance_name'].to_s
      end
    end
  end
end
