module Bosh::Monitor
  module YamlHelper

    def load_yaml_file(path, expected_type = Hash)
      raise(ConfigError, "Cannot find file '#{path}'") unless File.exists?(path)
      yaml = Psych.load_file(path)

      if expected_type && !yaml.is_a?(expected_type)
        raise ConfigError, "Incorrect file format in '#{path}', #{expected_type} expected"
      end

      yaml
    rescue SystemCallError => e
      raise ConfigError, "Cannot load YAML file at '#{path}': #{e}"
    end

  end
end
