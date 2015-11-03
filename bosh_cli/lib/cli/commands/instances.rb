# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Instances < Base
    usage 'instances'
    desc 'List all instances in a deployment'
    option '--details', 'Return detailed instance information'
    option '--dns', 'Return instance DNS A records'
    option '--vitals', 'Return instance vitals information'
    option '--ps', "Return instance process information"
    option '--failing', "Only show failing ones"
    def list()
      auth_required
      deployment_required
      manifest = Bosh::Cli::Manifest.new(deployment, director)
      manifest.load
      deployment_name = manifest.name

      deps = director.list_deployments
      selected = deps.select { |dep| dep['name'] == deployment_name }
      err("The deployment '#{deployment_name}' doesn't exist") if selected.size == 0

      show_current_state(deployment_name)
      no_track_unsupported

      unless deployment_name.nil?
        show_deployment(deployment_name, options)
      end
    end

    def show_deployment(name, options={})
      instances = director.fetch_vm_state(name)
      instance_count = instances.size

      if instances.empty?
        nl
        say('No instances')
        nl
        return
      end

      sorted = instances.sort do |a, b|
        s = a['job_name'].to_s <=> b['job_name'].to_s
        s = a['index'].to_i <=> b['index'].to_i if s == 0
        s = a['resource_pool'].to_s <=> b['resource_pool'].to_s if s == 0
        s
      end

      row_count = 0
      has_disk_cid = instances[0].has_key?('disk_cid')

      instances_table = table do |t|
        headings = ['Instance', 'State', 'Resource Pool', 'IPs']
        if options[:details]
          if has_disk_cid
            headings += ['VM CID', 'Disk CID', 'Agent ID', 'Resurrection']
          else
            headings += ['VM CID', 'Agent ID', 'Resurrection']
          end
        end
        if options[:dns]
          headings += ['DNS A records']
        end
        if options[:vitals]
          headings += [{:value => "Load\n(avg01, avg05, avg15)", :alignment => :center}]
          headings += ["CPU\nUser", "CPU\nSys", "CPU\nWait"]
          headings += ['Memory Usage', 'Swap Usage']
          headings += ["System\nDisk Usage", "Ephemeral\nDisk Usage", "Persistent\nDisk Usage"]
        end
        t.headings = headings
        sorted.each do |instance|
          if options[:failing]
            if options[:ps]
              instance['processes'].keep_if { |p| p['state'] != 'running' }
              if instance['processes'].size == 0 && instance['job_state'] == 'running'
                instance_count -= 1
                next
              end
            else
              if instance['job_state'] == 'running'
                instance_count -= 1
                next
              end
            end
          end

          row_count += 1

          job = "#{instance['job_name'] || 'unknown'}/#{instance['index'] || 'unknown'}"
          ips = Array(instance['ips']).join("\n")
          dns_records = Array(instance['dns']).join("\n")
          vitals = instance['vitals']

          row = [job, instance['job_state'], instance['resource_pool'], ips]

          if options[:details]
            if has_disk_cid
              row += [instance['vm_cid'], instance['disk_cid'] || 'n/a', instance['agent_id'], instance['resurrection_paused'] ? 'paused' : 'active']
            else
              row += [instance['vm_cid'], instance['agent_id'], instance['resurrection_paused'] ? 'paused' : 'active']
            end
          end

          if options[:dns]
            row += [dns_records.empty? ? 'n/a' : dns_records]
          end

          if options[:vitals]
            if vitals
              cpu =  vitals['cpu']
              mem =  vitals['mem']
              swap = vitals['swap']
              disk = vitals['disk']

              row << vitals['load'].join(', ')
              row << "#{cpu['user']}%"
              row << "#{cpu['sys']}%"
              row << "#{cpu['wait']}%"
              row << "#{mem['percent']}% (#{pretty_size(mem['kb'].to_i * 1024)})"
              row << "#{swap['percent']}% (#{pretty_size(swap['kb'].to_i * 1024)})"
              row << "#{disk['system']['percent']}%"
              if disk['ephemeral'].nil?
                row << 'n/a'
              else
                row << "#{disk['ephemeral']['percent']}%"
              end
              if disk['persistent'].nil?
                row << 'n/a'
              else
                row << "#{disk['persistent']['percent']}%"
              end
            else
              9.times { row << 'n/a' }
            end
          end

          t << row
          if options[:ps] && instance['processes']
            instance['processes'].each do |process|
              name = process['name']
              state = process['state']
              process_row = ["  #{name}", "#{state}"]
              (headings.size - 2).times { process_row << '' }
              t << process_row
            end

            t << :separator if row_count < instance_count
          end
        end
      end

      if options[:failing] && row_count == 0
        nl
        say('No failing instances')
        nl
        return
      end
      nl
      say(instances_table)
      nl
      say('Instances total: %d' % row_count )
    end
  end
end
