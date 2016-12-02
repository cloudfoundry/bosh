require 'cli/core_ext'

module Bosh::Cli::Command
  class CpiConfig < Base
    usage 'cpi-config'
    desc 'Download the current cpi config for the director'

    def show
      auth_required
      show_current_state

      config = director.get_cpi_config
      if !config.nil?
        say(config.properties)
      end
    end

    usage 'update cpi-config'
    desc 'Update the current cpi config for the director'

    def update(cpi_config_path)
      auth_required
      show_current_state

      cpi_config_yaml = read_yaml_file(cpi_config_path)

      if director.update_cpi_config(cpi_config_yaml)
        say("Successfully updated cpi config")
      else
        err("Failed to update cpi config")
      end
    end
  end
end
