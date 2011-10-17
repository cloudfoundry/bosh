module Bosh::Cli::Command
  class Vms < Base

    def list(deployment)
      auth_required

      vms = director.list_vms(deployment)

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
