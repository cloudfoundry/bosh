require 'cli/core_ext'

module Bosh::Cli::Command
  class RuntimeConfig < Base
    usage 'runtime-config'
    desc 'Download the current runtime config for the director'

    def show
      auth_required
      show_current_state

      config = director.get_runtime_config
      if !config.nil?
        say(config.properties)
      end
    end

    usage 'update runtime-config'
    desc 'Update the current runtime config for the director'

    def update(runtime_config_path)
      auth_required
      show_current_state

      runtime_config_yaml = read_yaml_file(runtime_config_path)

      if director.update_runtime_config(runtime_config_yaml)
        say("Successfully updated runtime config")
      else
        err("Failed to update runtime config")
      end
    end
  end
end
