# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class JobManagement < Base
    FORCE = 'Proceed even when there are other manifest changes'

    # bosh start
    usage 'start'
    desc 'Start job/instance'
    option '--force', FORCE
    def start_job(job, index = nil)
      change_job_state(:start, job, index)
    end

    # bosh stop
    usage 'stop'
    desc 'Stop job/instance'
    option '--soft', 'Stop process only'
    option '--hard', 'Power off VM'
    option '--force', FORCE
    def stop_job(job, index = nil)
      if hard?
        change_job_state(:detach, job, index)
      else
        change_job_state(:stop, job, index)
      end
    end

    # bosh restart
    usage 'restart'
    desc 'Restart job/instance (soft stop + start)'
    option '--force', FORCE
    def restart_job(job, index = nil)
      change_job_state(:restart, job, index)
    end

    # bosh recreate
    usage 'recreate'
    desc 'Recreate job/instance (hard stop + start)'
    option '--force', FORCE
    def recreate_job(job, index = nil)
      change_job_state(:recreate, job, index)
    end

    private

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

      def initialize(command, force = false)
        @command = command
        @force = force
      end

      def change(state, job, index)
        job_desc = job_description(job, index)
        op_desc = OPERATION_DESCRIPTIONS.fetch(state) % job_desc
        new_state = NEW_STATES.fetch(state)
        completion_desc = COMPLETION_DESCRIPTIONS.fetch(state) % job_desc.make_green

        status, task_id = perform_vm_state_change(job, index, new_state, op_desc)
        command.task_report(status, task_id, completion_desc)
      end

      private
      attr_reader :command

      def force?
        !!@force
      end

      def job_description(job, index)
        index ? "#{job}/#{index}" : "#{job}"
      end

      def perform_vm_state_change(job, index, new_state, operation_desc)
        command.say("You are about to #{operation_desc.make_green}")
        manifest = command.prepare_deployment_manifest
        manifest_yaml = Psych.dump(manifest)

        if command.interactive?
          check_if_manifest_changed(manifest)

          unless command.confirmed?("#{operation_desc.capitalize}?")
            command.cancel_deployment
          end
        end

        command.nl
        command.say("Performing `#{operation_desc}'...")
        command.director.change_job_state(manifest['name'], manifest_yaml, job, index, new_state)
      end

      def check_if_manifest_changed(manifest)
        other_changes_present = command.inspect_deployment_changes(
            manifest, :show_empty_changeset => false)

        if other_changes_present && !force?
          command.err('Cannot perform job management when other deployment changes ' +
                  "are present. Please use `--force' to override.")
        end
      end
    end

    def change_job_state(state, job, index = nil)
      check_arguments(state, job)
      index = valid_index_for(job, index)
      JobState.new(self, force?).change(state, job, index)
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

      if !hard_and_soft_options_allowed?(operation) && (hard? || soft?)
        err("--hard and --soft options only make sense for `stop' operation")
      end
    end

    def hard_and_soft_options_allowed?(operation)
      operation == :stop || operation == :detach
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
