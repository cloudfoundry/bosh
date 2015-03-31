require 'cli/terminal'

module Bosh::Cli::Command
  class CloudConfig < Base

    usage 'update cloud-config'
    desc 'Update the current cloud config for the director'
    def update(cloud_config_path)
      auth_required

      cloud_config_yaml = load_yaml_file(cloud_config_path)

      if director.update_cloud_config(cloud_config_yaml)
        say("Successfully updated cloud config")
      else
        err("Failed to update cloud config")
      end
    end
  end
end
