# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Vms < Base
    include Bosh::Cli::DeploymentHelper

    usage "vms"
    desc  "List all VMs that in a deployment"
    option "--full", "Return detailed VM information"
    def list(deployment_name = nil)
      auth_required
      no_track_unsupported
      show_full_stats = options[:full]

      if deployment_name.nil?
        deployment_required
        manifest = prepare_deployment_manifest
        deployment_name = manifest["name"]
      end

      say("Deployment `#{deployment_name.green}'")
      vms = director.fetch_vm_state(deployment_name)
      err("No VMs") if vms.empty?

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
          job = "#{vm["job_name"] || "unknown"}/#{vm["index"] || "unknown"}"
          ips = Array(vm["ips"]).join(", ")

          row = [job, vm["job_state"], vm["resource_pool"], ips]
          row += [vm["vm_cid"], vm["agent_id"]] if show_full_stats

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
