require 'cli/core_ext'

module Bosh::Cli::Command
  class CloudConfig < Base
    usage 'cloud-config'
    desc 'Download the current cloud config for the director'

    def show
      auth_required

      config = director.get_cloud_config
      if !config.nil?
        say(config.properties)
      end
    end

    usage 'update cloud-config'
    desc 'Update the current cloud config for the director'

    def update(cloud_config_path)
      auth_required

      cloud_config_yaml = read_yaml_file(cloud_config_path)

      if director.update_cloud_config(cloud_config_yaml)
        say("Successfully updated cloud config")
      else
        err("Failed to update cloud config")
      end
    end
  end
end
