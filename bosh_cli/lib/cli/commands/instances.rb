module Bosh::Cli::Command
  class Instances < Base
    usage 'instances'
    desc 'List all instances in a deployment'
    option '--details', 'Return detailed instance information'
    option '--dns', 'Return instance DNS A records'
    option '--vitals', 'Return instance vitals information'
    option '--ps', "Return instance process information"
    option '--failing', "Only show failing ones"
    def list
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

      if instances.empty?
        nl
        say('No instances')
        nl
        return
      end

      sorted = sort(instances)

      has_disk_cid = instances.any? {|instance| instance.has_key? 'disk_cid'}
      has_az = instances.any? {|instance| instance.has_key? 'availability_zone' }

      instances_table, row_count = construct_table_to_display(has_disk_cid, has_az, options, sorted)

      if options[:failing] && row_count == 0
        nl
        say('No failing instances')
        nl
        return
      end

      legend = '(*) Bootstrap node'

      nl
      say(instances_table)
      nl
      say(legend)
      nl
      say('Instances total: %d' % row_count)
    end

    private

    def construct_table_to_display(has_disk_cid, has_az, options, sorted)
      row_count = 0

      result = table do |display_table|

        headings = ['Instance', 'State']
        if has_az
          headings << 'AZ'
        end
        headings += ['Resource Pool', 'IPs']
        if options[:details]
          headings << 'VM CID'
          if has_disk_cid
            headings += ['Disk CID']
          end
          headings +=['Agent ID', 'Resurrection']
        end
        if options[:dns]
          headings += ['DNS A records']
        end
        if options[:vitals]
          headings += [{:value => "Load\n(avg01, avg05, avg15)", :alignment => :center}]
          headings += %W(CPU\nUser CPU\nSys CPU\nWait)
          headings += ['Memory Usage', 'Swap Usage']
          headings += ["System\nDisk Usage", "Ephemeral\nDisk Usage", "Persistent\nDisk Usage"]
        end
        display_table.headings = headings

        s = sorted.size
        sorted.each do |instance|
          if options[:failing]
            if options[:ps]
              instance['processes'].keep_if { |p| p['state'] != 'running' }
              next if instance['processes'].size == 0 && instance['job_state'] != 'failing'
            else
              next if instance['job_state'] != 'failing'
            end
          end

          row_count += 1
          display_table << :separator if row_count.between?(2, sorted.size)

          job_name = instance['job_name'] || 'unknown'
          index = instance['index'] || 'unknown'
          job = if instance.has_key?('instance_id')
                  is_bootstrap = instance.fetch('is_bootstrap', false)
                  if is_bootstrap
                    "#{job_name}/#{index} (#{instance['instance_id']})*"
                  else
                    "#{job_name}/#{index} (#{instance['instance_id']})"
                  end
                else
                  "#{job_name}/#{index}"
                end
          ips = Array(instance['ips']).join("\n")
          dns_records = Array(instance['dns']).join("\n")
          vitals = instance['vitals']
          az = instance['availability_zone'].nil? ? 'n/a' : instance['availability_zone']

          row = [job, instance['job_state']]
          if has_az
            row << az
          end

          if instance['resource_pool']
            row << instance['resource_pool']
          else
            row << instance['vm_type']
          end

          row << ips

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
              cpu = vitals['cpu']
              mem = vitals['mem']
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

          display_table << row
          s -= 1
          if options[:ps] && instance['processes']
            instance['processes'].each do |process|
              name = process['name']
              state = process['state']
              process_row = ["  #{name}", "#{state}"]
              (headings.size - 2).times { process_row << '' }
              display_table << process_row
            end
            display_table << :separator if s > 0
          end
        end
      end

      return result, row_count
    end

    def sort(instances)
      instances.sort do |instance1, instance2|
        comparison = instance1['job_name'].to_s <=> instance2['job_name'].to_s
        comparison = instance1['availability_zone'].to_s <=> instance2['availability_zone'].to_s if comparison == 0
        comparison = instance1['index'].to_i <=> instance2['index'].to_i if comparison == 0
        comparison = instance1['resource_pool'].to_s <=> instance2['resource_pool'].to_s if comparison == 0
        comparison
      end
    end
  end
end
