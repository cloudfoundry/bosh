# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  # This class encapsulates the details of handling dev and final releases:
  # also it partitions release metadata between final config (which is
  # under version control) and user dev config.
  class Release
    attr_reader :dir

    def initialize(dir)
      @dir = dir
      config_dir = File.join(dir, "config")
      @final_config_file = File.join(config_dir, "final.yml")
      @dev_config_file = File.join(config_dir, "dev.yml")

      @private_config_file = File.join(config_dir, "private.yml")

      unless File.directory?(dir)
        err("Cannot find release directory `#{dir}'")
      end

      unless File.directory?(config_dir)
        err("Cannot find release config directory `#{config_dir}'")
      end

      @final_config = load_config(@final_config_file)
      @dev_config = load_config(@dev_config_file)
      @private_config = load_config(@private_config_file)

      migrate_legacy_configs

      @final_config.recursive_merge!(@private_config)
    end

    # Devbox-specific attributes, gitignored
    [:dev_name, :latest_release_filename].each do |attr|
      define_method(attr) do
        @dev_config[attr.to_s]
      end

      define_method("#{attr}=".to_sym) do |value|
        @dev_config[attr.to_s] = value
      end
    end

    # Shared attributes, present in repo
    [:final_name, :min_cli_version].each do |attr|
      define_method(attr) do
        @final_config[attr.to_s]
      end

      define_method("#{attr}=".to_sym) do |value|
        @final_config[attr.to_s] = value
      end
    end

    # Picks blobstore client to use with current release.
    #
    # @return [Bosh::Blobstore::Client] blobstore client
    def blobstore
      return @blobstore if @blobstore
      blobstore_config = @final_config["blobstore"]

      if blobstore_config.nil?
        err("Missing blobstore configuration, please update your release")
      end

      provider = blobstore_config["provider"]
      options  = blobstore_config["options"] || {}

      @blobstore = Bosh::Blobstore::Client.create(provider,
                                                  symbolize_keys(options))

    rescue Bosh::Blobstore::BlobstoreError => e
      err("Cannot initialize blobstore: #{e}")
    end

    def save_config
      # TODO: introduce write_yaml helper
      File.open(@dev_config_file, "w") do |f|
        YAML.dump(@dev_config, f)
      end

      File.open(@final_config_file, "w") do |f|
        YAML.dump(@final_config, f)
      end
    end

    private

    # Upgrade path for legacy clients that kept release metadata
    # in config/dev.yml and config/final.yml
    #
    def migrate_legacy_configs
      # We're using blobstore_options as old config marker.
      # Unfortunately old CLI won't tell you to upgrade because it checks
      # for valid blobstore options first, so instead of removing
      # blobstore_options we mark it as deprecated, so new CLI proceeds
      # to migrate while the old one tells you to upgrade.
      if @dev_config.has_key?("blobstore_options") &&
          @dev_config["blobstore_options"] != "deprecated"
        say("Found legacy dev config file `#{@dev_config_file}'".yellow)

        new_dev_config = {
          "dev_name" => @dev_config["name"],
          "latest_release_filename" =>
              @dev_config["latest_release_filename"],

          # Following two options are only needed for older clients
          # to fail gracefully and never actually read by a new client
          "blobstore_options" => "deprecated",
          "min_cli_version" => "0.12"
        }

        @dev_config = new_dev_config

        File.open(@dev_config_file, "w") do |f|
          YAML.dump(@dev_config, f)
        end
        say("Migrated dev config file format".green)
      end

      if @final_config.has_key?("blobstore_options") &&
          @final_config["blobstore_options"] != "deprecated"
        say("Found legacy config file `#{@final_config_file}'".yellow)

        unless @final_config["blobstore_options"]["provider"] == "atmos" &&
            @final_config["blobstore_options"].has_key?("atmos_options")
          err("Please update your release to the version " +
                  "that uses Atmos blobstore")
        end

        new_final_config = {
          "final_name" => @final_config["name"],
          "min_cli_version" => @final_config["min_cli_version"],
          "blobstore" => {
            "provider" => "atmos",
            "options" => @final_config["blobstore_options"]["atmos_options"]
          },
          "blobstore_options" => "deprecated"
        }

        @final_config = new_final_config

        File.open(@final_config_file, "w") { |f| YAML.dump(@final_config, f) }
        say("Migrated final config file format".green)
      end
    end

    def symbolize_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_sym] = value
        h
      end
    end

    def load_config(file)
      if File.exists?(file)
        load_yaml_file(file)
      else
        {}
      end
    end

  end

end
