require 'cli/job_command_args'
require 'cli/resurrection'

module Bosh::Cli
  module Command
    class Vm < Base
      usage 'vm resurrection'
      desc 'Enable/Disable resurrection for a given vm'
      def resurrection_state(job=nil, index=nil, new_state)
        if job.nil? && index.nil?
          resurrection = Resurrection.new(new_state)

          director.change_vm_resurrection_for_all(resurrection.paused?)
        else
          job_args = JobCommandArgs.new([job, index])
          job, index, _ = job_args.to_a
          resurrection = Resurrection.new(new_state)

          job_must_exist_in_deployment(job)
          index = valid_index_for(job, index, integer_index: true)

          manifest           = prepare_deployment_manifest
          director.change_vm_resurrection(manifest['name'], job, index, resurrection.paused?)
        end
      end
    end
  end
end
