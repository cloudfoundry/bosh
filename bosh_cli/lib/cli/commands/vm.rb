module Bosh::Cli::Command
  class Vm < Base
    # bosh vm
    usage 'vm resurrection'
    desc 'Enable/Disable resurrection for a given vm'
    def resurrection_state(*args)
      job, index, resurrection_value = parse_args(args)
      job_must_exist_in_deployment(job)
      index = valid_index_for(job, index, integer_index: true)

      resurrection_value = resurrection_value.first
      manifest = prepare_deployment_manifest
      director.change_vm_resurrection(manifest['name'], job, index, resurrection_paused(resurrection_value))
    end

    private

    def resurrection_paused(value)
      case value
        when 'true','yes','on','enable' then false
        when 'false','no','off','disable' then true
      else
        err("Resurrection paused state should be on/off or true/false or yes/no, received #{value.inspect}")
      end
    end
  end
end
