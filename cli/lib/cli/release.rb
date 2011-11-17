module Bosh::Cli

  class Release

    DEFAULT_CONFIG = {
      "name" => nil,
      "jobs_order" => [],
      "min_cli_version" => "0.5",
      "s3_options" => { },
      "atmos_options" => { },
      "latest_release_filename" => nil
    }

    def self.dev(release_dir)
      new(release_dir, false)
    end

    def self.final(release_dir)
      new(release_dir, true)
    end

    attr_reader :config

    def initialize(release_dir, final = false)
      @release_dir = release_dir
      @final  = final
      @config_file = File.join(@release_dir, "config", final ? "final.yml" : "dev.yml")
      @config = reload_config
    end

    DEFAULT_CONFIG.keys.each do |attr|
      define_method(attr) do
        @config[attr.to_s]
      end
    end

    def final?
      @final
    end

    def update_config(attrs = { })
      @config = @config.merge(stringify_keys(attrs))

      FileUtils.mkdir_p(File.dirname(@config_file))
      FileUtils.touch(@config_file)

      File.open(@config_file, "w") do |f|
        f.write(YAML.dump(@config))
      end

      reload_config
    end

    def reload_config
      if File.exists?(@config_file)
        config = load_yaml_file(@config_file) rescue nil
        unless config.is_a?(Hash)
          raise InvalidRelease, "Can't read release configuration from `#{@config_file}'"
        end
        config
      elsif final?
        DEFAULT_CONFIG
      else
        final_release = self.class.final(@release_dir)
        DEFAULT_CONFIG.merge("jobs_order" => final_release.jobs_order,
                             "min_cli_version" => final_release.min_cli_version)
      end
    end

    private

    def stringify_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_s] = value
        h
      end
    end

  end

end
