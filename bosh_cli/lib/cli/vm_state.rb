module Bosh::Cli
  class VmState
    def initialize(command, manifest, force)
      @command = command
      @manifest = manifest
      @force = force
    end

    def change(job, index, new_state, operation_desc)
      command.say("You are about to #{operation_desc.make_green}")

      if command.interactive?
        check_if_manifest_changed(@manifest.hash)

        unless command.confirmed?("#{operation_desc.capitalize}?")
          command.cancel_deployment
        end
      end

      command.nl
      command.say("Performing `#{operation_desc}'...")
      command.director.change_job_state(@manifest.name, @manifest.yaml, job, index, new_state)
    end

    private
    attr_reader :command

    def force?
      !!@force
    end

    def check_if_manifest_changed(manifest_hash)
      other_changes_present = command.inspect_deployment_changes(manifest_hash, show_empty_changeset: false)

      if other_changes_present && !force?
        command.err("Cannot perform job management when other deployment changes are present. Please use `--force' to override.")
      end
    end
  end
end
