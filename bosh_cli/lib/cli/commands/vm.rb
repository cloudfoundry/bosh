require 'cli/job_command_args'
require 'cli/resurrection'

module Bosh::Cli
  module Command
    class Vm < Base
      usage 'vm resurrection'
      desc 'Enable/Disable resurrection for a given vm'
      def resurrection_state(job=nil, index=nil, new_state)
        auth_required

        if job.nil? && index.nil?
          resurrection = Resurrection.new(new_state)
          show_current_state

          director.change_vm_resurrection_for_all(resurrection.paused?)
        else
          job_args = JobCommandArgs.new([job, index])
          job, index, _ = job_args.to_a
          resurrection = Resurrection.new(new_state)

          manifest = prepare_deployment_manifest(show_state: true)
          job_must_exist_in_deployment(manifest.hash, job)
          index = valid_index_for(manifest.hash, job, index, integer_index: true)

          director.change_vm_resurrection(manifest.name, job, index, resurrection.paused?)
        end
      end
    end
  end
end
