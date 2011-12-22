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

      begin
        vms = director.fetch_vm_state(name)
      rescue RuntimeError
        say("Error while fetching vm-states from director".red)
        vms = []
      end
      err("No VMs") if vms.size == 0

      sorted = vms.sort do |a, b|
        s = b["job_name"].to_s <=> a["job_name"].to_s
        s = a["index"].to_i <=> b["index"].to_i if s == 0
        s = a["resource_pool"].to_s <=> b["resource_pool"].to_s if s == 0
        s
      end

      vms_table = table do |t|
        t.headings = "Job", "CID", "Agent ID", "Job-State", "Resource-Pool", "IPs"
        sorted.each do |vm|
          ips = ""
          vm["ips"].each {|ip| ips += ip + " " } if vm["ips"]
          job = "#{vm["job_name"]}/#{vm["index"]}" if vm["job_name"]
          t << [job, vm["vm_cid"], vm["agent_id"], vm["job_state"], vm["resource_pool"], ips]
        end
      end

      say("\n")
      say(vms_table)
      say("\n")
      say("VMs total: %d" % vms.size)
    end

  end
end
