# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Vitals < Base
    include Bosh::Cli::DeploymentHelper

    usage "vitals"
    desc  "List all VMs vitals that are in a deployment"
    def vitals(deployment_name = nil)
      auth_required

      if deployment_name.nil?
        deployment_required
        manifest = prepare_deployment_manifest
        deployment_name = manifest["name"]
      end

      say("Deployment `#{deployment_name.green}'")
      vms = director.fetch_vm_vitals(deployment_name)
      err("No VMs") if vms.empty?

      sorted = vms.sort do |a, b|
        s = a["job_name"].to_s <=> b["job_name"].to_s
        s = a["index"].to_i <=> b["index"].to_i if s == 0
        s
      end

      vitals_table = table do |t|
        headings = ["Job/index", "State"]
        headings << {:value => "Load\n(avg01, avg05, avg15)",
                     :alignment => :center}
        headings << "CPU\nUser"
        headings << "CPU\nSys"
        headings << "CPU\nWait"
        headings << "Memory Usage"
        headings << "Swap Usage"
        headings << "System\nDisk Usage"
        headings << "Ephemeral\nDisk Usage"
        headings << "Persistent\nDisk Usage"

        t.headings = headings

        sorted.each do |vm|
          job = "#{vm["job_name"] || "unknown"}/#{vm["index"] || "unknown"}"
          vitals = vm["vitals"]

          row = [job, vm["job_state"]]
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
            row << "#{disk["ephemeral"]["percent"]}%"
            if disk["persistent"].nil?
              row << "n/a"
            else
              row << "#{disk["persistent"]["percent"]}%"
            end
          else
            9.times { row << "n/a" }
          end

          t << row
        end
      end

      nl
      say(vitals_table)
      nl
      say("VMs total: %d" % vms.size)
    end

  end
end
