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
      vms = director.list_vms(name)
      err("No VMs") if vms.size == 0

      sorted = vms.sort do |a, b|
        s = a["job"].to_s <=> b["job"].to_s
        s = a["index"].to_i <=> b["index"].to_i if s == 0
        s
      end

      vms_table = table do |t|
        t.headings = "Instance", "CID", "Agent ID"
        sorted.each do |vm|
          job = vm["job"]
          index = vm["index"]
          instance = job ? "#{job}/#{index}" : ""
          t << [ instance, vm["cid"], vm["agent_id"] ]
        end
      end

      say("\n")
      say(vms_table)
      say("\n")
      say("VMs total: %d" % vms.size)
    end

  end
end
