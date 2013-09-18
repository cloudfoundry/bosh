require 'cli/job_command_args'
require 'cli/resurrection'

module Bosh::Cli
  module Command
    class Vm < Base
      usage 'vm resurrection'
      desc 'Enable/Disable resurrection for a given vm'
      def resurrection_state(*args)
        if args.size == 1
          resurrection_state = args.first
          resurrection = Resurrection.new(resurrection_state)

          director.change_vm_resurrection_for_all(resurrection.paused?)
        else
          job, index, remaining_args = JobCommandArgs.new(args).to_a
          resurrection_state = remaining_args.first
          resurrection = Resurrection.new(resurrection_state)

          job_must_exist_in_deployment(job)
          index = valid_index_for(job, index, integer_index: true)

          manifest           = prepare_deployment_manifest
          director.change_vm_resurrection(manifest['name'], job, index, resurrection.paused?)
        end
      end
    end
  end
end
