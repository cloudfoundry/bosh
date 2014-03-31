module Bosh::Agent
  class Infrastructure::Dummy
    def load_settings
      agent_env_from_cpi_path = File.join(Config.base_dir, 'bosh', 'dummy-cpi-agent-env.json')
      JSON.parse(File.read(agent_env_from_cpi_path))
    rescue Errno::ENOENT
      raise Bosh::Agent::LoadSettingsError, 'Failed to read/write env/dummy-cpi-agent-env.json'
    end

    def get_network_settings(network_name, properties)
      # Nothing to do
    end
  end
end
