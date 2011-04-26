module Bosh::Cli
  module YamlHelper

    def load_yaml_file(path, expected_type = Hash)
      err("Cannot find file `#{path}'") unless File.exists?(path)
      yaml = YAML.load_file(path)

      if expected_type && !yaml.is_a?(expected_type)
        err("Incorrect file format in `#{path}', #{expected_type} expected")
      end

      yaml
    rescue SystemCallError => e
      err("Cannot load YAML file at `#{path}': #{e}")
    end

  end
end
