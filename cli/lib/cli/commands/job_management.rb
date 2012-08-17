# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class JobManagement < Base
    include Bosh::Cli::DeploymentHelper

    # usage  "start <job> [<index>]"
    # desc   "Start job/instance"
    # power_option "--force"
    # route  :job_management, :start_job
    def start_job(*args)
      change_job_state(:start, *args)
    end

    # usage  "stop <job> [<index>]"
    # desc   "Stop job/instance"
    # option "--soft", "stop process only"
    # option "--hard", "power off VM"
    # power_option "--force"
    # route  :job_management, :stop_job
    def stop_job(*args)
      change_job_state(:stop, *args)
    end

    # usage  "restart <job> [<index>]"
    # desc   "Restart job/instance (soft stop + start)"
    # power_option "--force"
    # route  :job_management, :restart_job
    def restart_job(*args)
      change_job_state(:restart, *args)
    end

    # usage "recreate <job> [<index>]"
    # desc  "Recreate job/instance (hard stop + start)"
    # power_option "--force"
    # route :job_management, :recreate_job
    def recreate_job(*args)
      change_job_state(:recreate, *args)
    end

    def change_job_state(operation, *args)
      auth_required
      manifest_yaml = prepare_deployment_manifest(:yaml => true)
      manifest = YAML.load(manifest_yaml)

      unless [:start, :stop, :restart, :recreate].include?(operation)
        err("Unknown operation `#{operation}': supported operations are " +
            "`start', `stop', `restart', `recreate'")
      end

      args  = args.dup
      hard  = args.delete("--hard")
      soft  = args.delete("--soft")
      force = args.delete("--force")

      if hard && soft
        err("Cannot handle both --hard and --soft options, please choose one")
      end

      if operation != :stop && (hard || soft)
        err("--hard and --soft options only make sense for `stop' operation")
      end

      job = args.shift
      index = args.shift
      job_desc = index ? "#{job}(#{index})" : "#{job}"

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
        # TODO: refactor inspect_deployment_changes
        # to decouple changeset structure and rendering
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

      status, _ =
        director.change_job_state(manifest["name"],
                                  manifest_yaml,
                                  job, index, new_state)

      task_report(status, completion_desc)
    end

  end
end
