# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class JobManagement < Base
    include Bosh::Cli::DeploymentHelper

    FORCE = "Proceed even when there are other manifest changes"

    # bosh start
    usage "start"
    desc "Start job/instance"
    option "--force", FORCE
    def start_job(job, index = nil)
      change_job_state(:start, job, index)
    end

    # bosh stop
    usage "stop"
    desc "Stop job/instance"
    option "--soft", "Stop process only"
    option "--hard", "Power off VM"
    option "--force", FORCE
    def stop_job(job, index = nil)
      change_job_state(:stop, job, index)
    end

    # bosh restart
    usage "restart"
    desc "Restart job/instance (soft stop + start)"
    option "--force", FORCE
    def restart_job(job, index = nil)
      change_job_state(:restart, job, index)
    end

    # bosh recreate
    usage "recreate"
    desc "Recreate job/instance (hard stop + start)"
    option "--force", FORCE
    def recreate_job(job, index = nil)
      change_job_state(:recreate, job, index)
    end

    def change_job_state(operation, job, index)
      auth_required
      manifest_yaml = prepare_deployment_manifest(:yaml => true)
      manifest = YAML.load(manifest_yaml)

      unless [:start, :stop, :restart, :recreate].include?(operation)
        err("Unknown operation `#{operation}': supported operations are " +
            "`start', `stop', `restart', `recreate'")
      end

      hard = options[:hard]
      soft = options[:soft]
      force = options[:force]

      if hard && soft
        err("Cannot handle both --hard and --soft options, please choose one")
      end

      if operation != :stop && (hard || soft)
        err("--hard and --soft options only make sense for `stop' operation")
      end

      job_desc = index ? "#{job}/#{index}" : "#{job}"

      op_desc = nil
      new_state = nil
      completion_desc = nil

      case operation
      when :start
        op_desc = "start #{job_desc}"
        new_state = "started"
        completion_desc = "#{job_desc.green} has been started"
      when :stop
        if hard
          op_desc = "stop #{job_desc} and power off its VM(s)"
          completion_desc = "#{job_desc.green} has been stopped, " +
                            "VM(s) powered off"
          new_state = "detached"
        else
          op_desc = "stop #{job_desc}"
          completion_desc = "#{job_desc.green} has been stopped, " +
                            "VM(s) still running"
          new_state = "stopped"
        end
      when :restart
        op_desc = "restart #{job_desc}"
        new_state = "restart"
        completion_desc = "#{job_desc.green} has been restarted"
      when :recreate
        op_desc = "recreate #{job_desc}"
        new_state = "recreate"
        completion_desc = "#{job_desc.green} has been recreated"
      else
        err("Unknown operation: `#{operation}'")
      end

      say("You are about to #{op_desc.green}")

      if interactive?
        other_changes_present = inspect_deployment_changes(
            manifest, :show_empty_changeset => false)

        if other_changes_present && !force
          err("Cannot perform job management when other deployment changes " +
              "are present. Please use `--force' to override.")
        end
        unless confirmed?("#{op_desc.capitalize}?")
          cancel_deployment
        end
      end

      nl
      say("Performing `#{op_desc}'...")

      status, task_id = director.change_job_state(
        manifest["name"], manifest_yaml, job, index, new_state)

      task_report(status, task_id, completion_desc)
    end

  end
end
