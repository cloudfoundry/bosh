module Bosh::Agent
  class Infrastructure::Dummy
    def load_settings
      agent_env_from_cpi_path = File.join(Config.base_dir, 'bosh', 'agent-env.json')
      JSON.parse(File.read(agent_env_from_cpi_path))
    end

    def get_network_settings(network_name, properties)
      # Nothing to do
    end
  end
end
