# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class JobManagement < Base
    FORCE = 'Proceed even when there are other manifest changes'

    # bosh start
    usage 'start'
    desc 'Start job/instance'
    option '--force', FORCE
    def start_job(job, index = nil)
      check_arguments(:start, job)

      job_desc = job_description(job, index)
      op_desc = "start #{job_desc}"
      new_state = 'started'
      completion_desc = "#{job_desc.make_green} has been started"

      status, task_id = perform_vm_state_change(job, index, new_state, op_desc)
      task_report(status, task_id, completion_desc)
    end

    # bosh stop
    usage 'stop'
    desc 'Stop job/instance'
    option '--soft', 'Stop process only'
    option '--hard', 'Power off VM'
    option '--force', FORCE
    def stop_job(job, index = nil)
      check_arguments(:stop, job)

      job_desc = job_description(job, index)
      if hard?
        op_desc = "stop #{job_desc} and power off its VM(s)"
        completion_desc = "#{job_desc.make_green} has been detached, " +
            'VM(s) powered off'
        new_state = 'detached'
      else
        op_desc = "stop #{job_desc}"
        completion_desc = "#{job_desc.make_green} has been stopped, " +
            'VM(s) still running'
        new_state = 'stopped'
      end

      status, task_id = perform_vm_state_change(job, index, new_state, op_desc)
      task_report(status, task_id, completion_desc)
    end

    # bosh restart
    usage 'restart'
    desc 'Restart job/instance (soft stop + start)'
    option '--force', FORCE
    def restart_job(job, index = nil)
      check_arguments(:restart, job)

      job_desc = job_description(job, index)
      op_desc = "restart #{job_desc}"
      new_state = 'restart'
      completion_desc = "#{job_desc.make_green} has been restarted"

      status, task_id = perform_vm_state_change(job, index, new_state, op_desc)
      task_report(status, task_id, completion_desc)
    end

    # bosh recreate
    usage 'recreate'
    desc 'Recreate job/instance (hard stop + start)'
    option '--force', FORCE
    def recreate_job(job, index = nil)
      check_arguments(:recreate, job)

      job_desc = job_description(job, index)
      op_desc = "recreate #{job_desc}"
      new_state = 'recreate'
      completion_desc = "#{job_desc.make_green} has been recreated"

      status, task_id = perform_vm_state_change(job, index, new_state, op_desc)
      task_report(status, task_id, completion_desc)
    end

    private

    def job_description(job, index)
      index ? "#{job}/#{index}" : "#{job}"
    end

    def hard?
      options[:hard]
    end

    def soft?
      options[:soft]
    end

    def force?
      options[:force]
    end

    def check_arguments(operation, job)
      auth_required
      job_must_exist_in_deployment(job)

      if hard? && soft?
        err('Cannot handle both --hard and --soft options, please choose one')
      end

      if operation != :stop && (hard? || soft?)
        err("--hard and --soft options only make sense for `stop' operation")
      end
    end

    def perform_vm_state_change(job, index, new_state, operation_desc)
      say("You are about to #{operation_desc.make_green}")
      manifest = prepare_deployment_manifest

      if interactive?
        check_if_manifest_changed(manifest)

        unless confirmed?("#{operation_desc.capitalize}?")
          cancel_deployment
        end
      end

      nl
      say("Performing `#{operation_desc}'...")
      manifest_yaml = Psych.dump(manifest)
      director.change_job_state(manifest['name'], manifest_yaml, job, index, new_state)
    end

    def check_if_manifest_changed(manifest)
      return if force?

      other_changes_present = inspect_deployment_changes(
          manifest, :show_empty_changeset => false)

      if other_changes_present
        err('Cannot perform job management when other deployment changes ' +
                "are present. Please use `--force' to override.")
      end
    end
  end
end
