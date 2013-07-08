# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Vms < Base
    usage "vms"
    desc  "List all VMs in a deployment"
    option "--details", "Return detailed VM information"
    option "--dns", "Return VM DNS A records"
    option "--vitals", "Return VM vitals information"
    def list(deployment_name = nil)
      auth_required
      no_track_unsupported

      if deployment_name.nil?
        deps = director.list_deployments
        err("No deployments") if deps.empty?
        deps.each { |dep| show_deployment(dep['name'], options) }
      else
        show_deployment deployment_name, options
      end
    end

    def show_deployment(name, options={})
      say("Deployment `#{name.make_green}'")
      vms = director.fetch_vm_state(name)
      err("No VMs") if vms.empty?

      sorted = vms.sort do |a, b|
        s = a["job_name"].to_s <=> b["job_name"].to_s
        s = a["index"].to_i <=> b["index"].to_i if s == 0
        s = a["resource_pool"].to_s <=> b["resource_pool"].to_s if s == 0
        s
      end

      vms_table = table do |t|
        headings = ["Job/index", "State", "Resource Pool", "IPs"]
        if options[:details]
          headings += ["CID", "Agent ID", "Resurrection"]
        end
        if options[:dns]
          headings += ["DNS A records"]
        end
        if options[:vitals]
          headings += [{:value => "Load\n(avg01, avg05, avg15)", :alignment => :center}]
          headings += ["CPU\nUser", "CPU\nSys", "CPU\nWait"]
          headings += ["Memory Usage", "Swap Usage"]
          headings += ["System\nDisk Usage", "Ephemeral\nDisk Usage", "Persistent\nDisk Usage"]
        end
        t.headings = headings

        sorted.each do |vm|
          job = "#{vm["job_name"] || "unknown"}/#{vm["index"] || "unknown"}"
          ips = Array(vm["ips"]).join(", ")
          dns_records = Array(vm["dns"]).join("\n")
          vitals = vm["vitals"]

          row = [job, vm["job_state"], vm["resource_pool"], ips]

          if options[:details]
            row += [vm["vm_cid"], vm["agent_id"], vm["resurrection_paused"] ? 'paused' : 'active']
          end

          if options[:dns]            
            row += [dns_records.empty? ? "n/a" : dns_records]
          end

          if options[:vitals]
            if vitals
              cpu =  vitals["cpu"]
              mem =  vitals["mem"]
              swap = vitals["swap"]
              disk = vitals["disk"]

              row << vitals["load"].map { |l| "#{l}%" }.join(", ")
              row << "#{cpu["user"]}%"
              row << "#{cpu["sys"]}%"
              row << "#{cpu["wait"]}%"
              row << "#{mem["percent"]}% (#{pretty_size(mem["kb"].to_i * 1024)})"
              row << "#{swap["percent"]}% (#{pretty_size(swap["kb"].to_i * 1024)})"
              row << "#{disk["system"]["percent"]}%"
              if disk["ephemeral"].nil?
                row << "n/a"
              else
                row << "#{disk["ephemeral"]["percent"]}%"
              end
              if disk["persistent"].nil?
                row << "n/a"
              else
                row << "#{disk["persistent"]["percent"]}%"
              end
            else
              9.times { row << "n/a" }
            end
          end

          t << row
        end
      end

      nl
      say(vms_table)
      nl
      say("VMs total: %d" % vms.size)
    end

  end
end
