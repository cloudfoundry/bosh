module Bosh::Cli::Command
  class Vms < Base
    include Bosh::Cli::DeploymentHelper

    def list(*args)
      auth_required
      name = args.first

      if name.nil?
        deployment_required
        manifest = prepare_deployment_manifest
        name = manifest["name"]
      end

      say("Deployment `#{name.green}'")
      vms = []
      director.fetch_vm_state(name) do |output|
        output.to_s.split("\n").each do |line|
          vm_stat = JSON.parse(line)
          vms << [ vm_stat["job_name"], vm_stat["index"],
                   vm_stat["vm_cid"], vm_stat["agent_id"],
                   vm_stat["job_state"], vm_stat["resource_pool"],
                   vm_stat["ips"] ]
        end
        # We'll print the result later.
        ""
      end
      err("No VMs") if vms.size == 0

      sorted = vms.sort do |a, b|
        s = b[0].to_s <=> a[0].to_s # job-name
        s = a[1].to_i <=> b[1].to_i if s == 0 # index
        s = a[5].to_s <=> b[5].to_s if s == 0 # if idle vm -> sort by resource-pool
        s
      end

      vms_table = table do |t|
        t.headings = "Job-Name", "Index", "CID", "Agent ID", "Job-State", "Resource-Pool", "IPs"
        sorted.each do |vm|
          t << vm
        end
      end

      say("\n")
      say(vms_table)
      say("\n")
      say("VMs total: %d" % vms.size)
    end

  end
end
