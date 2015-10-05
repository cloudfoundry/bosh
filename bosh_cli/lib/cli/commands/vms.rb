# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Vms < Base
    usage 'vms'
    desc 'List all VMs in a deployment'
    option '--details', 'Return detailed VM information'
    option '--dns', 'Return VM DNS A records'
    option '--vitals', 'Return VM vitals information'
    def list(deployment_name = nil)
      auth_required
      show_current_state(deployment_name)
      no_track_unsupported

      if deployment_name.nil?
        deps = director.list_deployments
        err('No deployments') if deps.empty?
        deps.each do |dep|
          say("Deployment `#{dep['name'].make_green}'")
          show_deployment(dep['name'], options)
        end
      else
        show_deployment deployment_name, options
      end
    end

    def show_deployment(name, options={})
      vms = director.fetch_vm_state(name)

      if vms.empty?
        nl
        say('No VMs')
        nl
        return
      end

      sorted = sort(vms)

      has_az = vms.any? {|vm| vm.has_key? 'availability_zone' }

      vms_table = table do |t|
        headings = ['VM', 'State']

        if has_az
          headings << 'AZ'
        end
        headings += ['Resource Pool', 'IPs']

        if options[:details]
          headings += ['CID', 'Agent ID', 'Resurrection']
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

        sorted.each do |vm|
          job_name = vm['job_name'] || 'unknown'
          job_index = vm['index'] || 'unknown'
          job = vm.has_key?('instance_id') ? "#{job_name}/#{job_index} (#{vm['instance_id']})" : "#{job_name}/#{job_index}"
          ips = Array(vm['ips']).join("\n")
          dns_records = Array(vm['dns']).join("\n")
          vitals = vm['vitals']
          az = vm['availability_zone'].nil? ? 'n/a' : vm['availability_zone']

          row = [job, vm['job_state']]
          if has_az
            row << az
          end

          if vm['resource_pool']
            row << vm['resource_pool']
          else
            row << vm['vm_type']
          end

          row << ips

          if options[:details]
            row += [vm['vm_cid'], vm['agent_id'], vm['resurrection_paused'] ? 'paused' : 'active']
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
        end
      end

      nl
      say(vms_table)
      nl
      say('VMs total: %d' % vms.size)
    end

    def sort(vms)
      sorted = vms.sort do |a, b|
        comparison = a['job_name'].to_s <=> b['job_name'].to_s
        comparison = a['availability_zone'].to_s <=> b['availability_zone'].to_s if comparison == 0
        comparison = a['index'].to_i <=> b['index'].to_i if comparison == 0
        comparison = a['resource_pool'].to_s <=> b['resource_pool'].to_s if comparison == 0
        comparison
      end
      sorted
    end

  end
end
