module Bosh::Cli
  class JobState
    OPERATION_DESCRIPTIONS = {
        start: 'start %s',
        stop: 'stop %s',
        detach: 'stop %s and power off its VM(s)',
        restart: 'restart %s',
        recreate: 'recreate %s'
    }

    NEW_STATES = {
        start: 'started',
        stop: 'stopped',
        detach: 'detached',
        restart: 'restart',
        recreate: 'recreate'
    }

    COMPLETION_DESCRIPTIONS = {
        start: '%s has been started',
        stop: '%s has been stopped, VM(s) still running',
        detach: '%s has been detached, VM(s) powered off',
        restart: '%s has been restarted',
        recreate: '%s has been recreated'
    }

    def initialize(command, vm_state, options)
      @command = command
      @vm_state = vm_state
      @options = options
    end

    def change(state, job, index)
      job_desc = job_description(job, index)
      op_desc = OPERATION_DESCRIPTIONS.fetch(state) % job_desc
      new_state = NEW_STATES.fetch(state)
      completion_desc = COMPLETION_DESCRIPTIONS.fetch(state) % job_desc.make_green

      status, task_id = perform_vm_state_change(job, index, new_state, op_desc)

      [status, task_id, completion_desc]
    end

    private
    attr_reader :command, :vm_state

    def job_description(job, index)
      index ? "#{job}/#{index}" : "#{job}"
    end

    def perform_vm_state_change(job, index, new_state, operation_desc)
      vm_state.change(job, index, new_state, operation_desc, @options)
    end
  end
end
