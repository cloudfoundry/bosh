# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Vms < Base
    include Bosh::Cli::DeploymentHelper

    # usage "vms [<deployment>]"
    # desc  "List all VMs that supposed to be in a deployment"
    # route :vms, :list
    def list(*args)
      auth_required

      show_full_stats = !args.delete("--full").nil?
      name = args.first

      if name.nil?
        deployment_required
        manifest = prepare_deployment_manifest
        name = manifest["name"]
      end

      say("Deployment #{name.green}")

      vms = director.fetch_vm_state(name)
      err("No VMs") if vms.size == 0

      sorted = vms.sort do |a, b|
        s = a["job_name"].to_s <=> b["job_name"].to_s
        s = a["index"].to_i <=> b["index"].to_i if s == 0
        s = a["resource_pool"].to_s <=> b["resource_pool"].to_s if s == 0
        s
      end

      vms_table = table do |t|
        headings = ["Job/index", "State", "Resource Pool", "IPs"]
        headings += ["CID", "Agent ID"] if show_full_stats

        t.headings = headings

        sorted.each do |vm|
          job = "#{vm["job_name"]}/#{vm["index"]}" if vm["job_name"]
          row = [job, vm["job_state"],
                 vm["resource_pool"], Array(vm["ips"]).join(", ")]
          row += [vm["vm_cid"], vm["agent_id"]] if show_full_stats
          t << row
        end
      end

      say("\n")
      say(vms_table)
      say("\n")
      say("VMs total: %d" % vms.size)
    end

  end
end
