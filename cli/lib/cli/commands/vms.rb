module Bosh::Cli::Command
  class Vms < Base
    include Bosh::Cli::DeploymentHelper

    def list(*args)
      auth_required

      if deployment.nil?
        case args.size
        when 0
          err("No deployment set")
        when 1
          name = args.first
        else
          err("Usage: bosh vms [<deployment>]")
        end
      else
        manifest = prepare_deployment_manifest
        name = manifest["name"]
        say("Using '#{name}' deployment")
      end

      vms = director.list_vms(name)

      err("No VMs") if vms.size == 0

      sorted = vms.sort do |a, b|
        s = a['job'] <=> b['job']
        if s == 0
          s = a['index'] <=> b['index']
        end
        s
      end

      vms_table = table do |t|
        t.headings = "Job", "Index", "CID", "Agent ID"
        sorted.each do |vm|
          t << [ vm["job"], vm["index"], vm["cid"], vm["agent_id"] ]
        end
      end

      say("\n")
      say(vms_table)
      say("\n")
      say("VMs total: %d" % vms.size)
    end

  end
end
