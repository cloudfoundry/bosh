require 'cli/job_command_args'
require 'cli/resurrection'

module Bosh::Cli
  module Command
    class Vm < Base
      usage 'vm resurrection'
      desc 'Enable/Disable resurrection for a given vm'
      def resurrection_state(job=nil, index_or_id=nil, new_state)
        auth_required

        if job.nil? && index_or_id.nil?
          resurrection = Resurrection.new(new_state)
          show_current_state

          director.change_vm_resurrection_for_all(resurrection.paused?)
        else
          job_args = JobCommandArgs.new([job, index_or_id])
          job, index_or_id, _ = job_args.to_a
          resurrection = Resurrection.new(new_state)

          manifest = prepare_deployment_manifest(show_state: true)
          director.change_vm_resurrection(manifest.name, job, index_or_id, resurrection.paused?)
        end
      end

      usage 'delete vm'
      desc 'Deletes a vm'
      def delete(vm_cid)
        auth_required

        unless confirmed?("Are you sure you want to delete vm '#{vm_cid}'?")
          say('Canceled deleting vm'.make_green)
          return
        end

        status, task_id = director.delete_vm_by_cid(vm_cid)
        task_report(status, task_id, "Deleted vm '#{vm_cid}'")
      end
    end
  end
end
