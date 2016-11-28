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

      instances_table, row_count = construct_table_to_display(options, sorted)

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

    def construct_table_to_display(options, instances)
      row_count = 0
      has_disk_cid = instances.any? {|instance| instance.has_key?('disk_cid') }
      has_az = instances.any? {|instance| instance.has_key?('az') }
      has_uptime = instances[0]['processes'] && instances[0]['processes'].size > 0 && instances[0]['processes'][0].has_key?('uptime')
      has_cpu = instances[0]['processes'] && instances[0]['processes'].size > 0 && instances[0]['processes'][0].has_key?('cpu')
      instance_count = instances.size

      result = table do |display_table|

        headings = ['Instance', 'State']
        if has_az
          headings << 'AZ'
        end
        headings += ['VM Type', 'IPs']
        if options[:details]
          headings << 'VM CID'
          if has_disk_cid
            headings += ['Disk CID']
          end
          headings += ['Agent ID', 'Resurrection', 'Ignore']
        end

        if options[:dns]
          headings += ['DNS A records']
        end

        instances_to_show = []
        instances.each do |instance|
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

          instances_to_show << instance
        end

        if options[:vitals]
          show_total = instance_count > 1 || instances_to_show[0]['processes'].size > 0

          headings += [{:value => 'Uptime', :alignment => :center}] if options[:ps] && has_uptime && show_total
          headings += [{:value => "Load\n(avg01, avg05, avg15)", :alignment => :center}]
          headings += [{:value => "CPU %\n(User, Sys, Wait)", :alignment => :center}]
          headings += ['CPU %'] if options[:ps] && has_cpu && show_total
          headings += ['Memory Usage', 'Swap Usage']
          headings += ["System\nDisk Usage", "Ephemeral\nDisk Usage", "Persistent\nDisk Usage"]
        end
        display_table.headings = headings

        last_job = ''
        instances_to_show.each do |instance|
          row_count += 1

          job_name = instance['job_name'] || 'unknown'
          index = instance['index'] || 'unknown'
          job = if instance.has_key?('id')
                  bootstrap = instance.fetch('bootstrap', false)
                  if bootstrap
                    "#{job_name}/#{instance['id']} (#{index})*"
                  else
                    "#{job_name}/#{instance['id']} (#{index})"
                  end
                else
                  "#{job_name}/#{index}"
                end
          ips = Array(instance['ips']).join("\n")
          dns_records = Array(instance['dns']).join("\n")
          vitals = instance['vitals']
          az = instance['az'].nil? ? 'n/a' : instance['az']

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

          display_table << :separator if row_count.between?(2, instance_count) && (options[:ps] || last_job != '' && instance['job_name'] != last_job)

          if options[:details]
            row << instance['vm_cid']
            row << (instance['disk_cid'] || 'n/a') if has_disk_cid
            row += [instance['agent_id'], instance['resurrection_paused'] ? 'paused' : 'active', instance['ignore'].nil? ? 'n/a' : instance['ignore']]
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

              row << '' if options[:ps] && has_uptime && instance['processes'].size > 0
              row << vitals['load'].join(', ')
              row << "#{cpu['user']}%, #{cpu['sys']}%, #{cpu['wait']}%"
              row << '' if options[:ps] && has_cpu && instance['processes'].size > 0
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
            display_table << row

            if options[:ps] && instance['processes']
              instance['processes'].each do |process|
                prow = ['  ' + process['name'], process['state'], '', '']
                if options[:details]
                  prow += ['','','']
                  prow << '' if has_disk_cid
                end
                prow << '' if has_az
                if has_uptime
                  if process['uptime'] && process['uptime']['secs']
                    uptime = Integer(process['uptime']['secs'])
                    days = uptime/60/60/24
                    hours = uptime/60/60%24
                    minutes = uptime/60%60
                    seconds = uptime%60
                    prow << "#{days}d #{hours}h #{minutes}m #{seconds}s"
                  else
                    prow << ''
                  end
                end
                prow += ['','']
                prow << (process['cpu'] ? "#{process['cpu']['total']}%":'') if has_cpu
                prow << (process['mem'] ? "#{process['mem']['percent']}% (#{pretty_size(process['mem']['kb'].to_i * 1024)})":'')
                4.times { prow << '' }
                display_table << prow
              end
            end
          else
            display_table << row
            if options[:ps] && instance['processes']
              instance['processes'].each do |process|
                name = process['name']
                state = process['state']
                process_row = ["  #{name}", "#{state}"]
                (headings.size - 2).times { process_row << '' }
                display_table << process_row
              end
            end
          end

          last_job = instance['job_name'] || 'unknown'
        end
        display_table.headings = headings
      end

      return result, row_count
    end

    def sort(instances)
      instances.sort do |instance1, instance2|
        comparison = instance1['job_name'].to_s <=> instance2['job_name'].to_s
        comparison = instance1['az'].to_s <=> instance2['az'].to_s if comparison == 0
        comparison = instance1['index'].to_i <=> instance2['index'].to_i if comparison == 0
        comparison
      end
    end
  end
end
