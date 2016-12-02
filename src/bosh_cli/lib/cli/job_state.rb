module Bosh::Cli
  class JobState
    OPERATION_DESCRIPTIONS = {
        start: 'start %s',
        stop: 'stop %s',
        detach: 'stop %s and delete its VM(s)',
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
        start: '%s started',
        stop: '%s stopped, VM(s) still running',
        detach: '%s detached, VM(s) deleted',
        restart: '%s restarted',
        recreate: '%s recreated'
    }

    def initialize(command, manifest, options)
      @command = command
      @manifest = manifest
      @options = options
    end

    def change(state, job, index_or_id, force)
      job, index_or_id = job.split('/') if index_or_id.nil?
      description = job_description(job, index_or_id)
      op_desc = OPERATION_DESCRIPTIONS.fetch(state) % description
      new_state = NEW_STATES.fetch(state)
      completion_desc = COMPLETION_DESCRIPTIONS.fetch(state) % description.make_green
      status, task_id = change_job_state(new_state, job, index_or_id, op_desc, force)

      [status, task_id, completion_desc]
    end

    private

    def change_job_state(new_state, job, index_or_id, operation_desc, force)
      @command.say("You are about to #{operation_desc.make_green}")

      check_if_manifest_changed(force)
      unless @command.confirmed?("#{operation_desc.capitalize}?")
        @command.cancel_deployment
      end

      @command.nl
      @command.say("Performing '#{operation_desc}'...")
      @command.director.change_job_state(@manifest.name, @manifest.yaml, job, index_or_id, new_state, @options)
    end


    def check_if_manifest_changed(force)
      other_changes_present = @command.inspect_deployment_changes(@manifest, show_empty_changeset: false)

      if other_changes_present && !force
        @command.err("Cannot perform job management when other deployment changes are present. Please use '--force' to override.")
      end
    end

    def job_description(job, index_or_id)
      return 'all jobs' if job == '*'
      index_or_id ? "#{job}/#{index_or_id}" : "#{job}/*"
    end
  end
end
