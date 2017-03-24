module Bosh::Registry
  module YamlHelper

    def load_yaml_file(path, expected_type = Hash)
      unless File.exists?(path)
        raise(ConfigError, "Cannot find file '#{path}'")
      end

      yaml = Psych.load_file(path)

      if expected_type && !yaml.is_a?(expected_type)
        raise ConfigError, "Incorrect file format in '#{path}', " \
                           "#{expected_type} expected"
      end

      yaml
    rescue SystemCallError => e
      raise ConfigError, "Cannot load YAML file at '#{path}': #{e}"
    end

  end
end
