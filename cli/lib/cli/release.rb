module Bosh::Cli

  # This class encapsulates the detals of handling dev and final releases:
  # also it partitions release metadata between public config (which is
  # under version control) and user private config.
  class Release
    attr_reader :dir

    def initialize(dir)
      @dir = dir
      config_dir = File.join(dir, "config")
      @public_config_file = File.join(config_dir, "final.yml")
      @private_config_file = File.join(config_dir, "dev.yml")

      unless File.directory?(dir)
        err("Cannot find release directory `#{dir}'")
      end

      unless File.directory?(config_dir)
        err("Cannot find release config directory `#{config_dir}'")
      end

      @public_config  = load_yaml_file(@public_config_file) rescue {}
      @private_config = load_yaml_file(@private_config_file) rescue {}
      migrate_legacy_configs
    end

    [:dev_name, :latest_release_filename].each do |attr|
      define_method(attr) do
        @private_config[attr.to_s]
      end

      define_method("#{attr}=".to_sym) do |value|
        @private_config[attr.to_s] = value
      end
    end

    [:final_name, :min_cli_version].each do |attr|
      define_method(attr) do
        @public_config[attr.to_s]
      end

      define_method("#{attr}=".to_sym) do |value|
        @public_config[attr.to_s] = value
      end
    end

    # Picks blobstore client to use with current release.
    #
    # @return [Bosh::Blobstore::Client] blobstore client
    def blobstore
      return @blobstore if @blobstore
      blobstore_config = @private_config["blobstore"] || @public_config["blobstore"]

      if blobstore_config.nil?
        err("Missing blobstore configuration, please update your release")
      end

      provider = blobstore_config["provider"]
      options  = blobstore_config["options"] || {}

      @blobstore = Bosh::Blobstore::Client.create(provider, symbolize_keys(options))

    rescue Bosh::Blobstore::BlobstoreError => e
      err("Cannot initialize blobstore: #{e}")
    end

    def save_config
      #TODO: introduce write_yaml helper
      File.open(@private_config_file, "w") do |f|
        YAML.dump(@private_config, f)
      end

      File.open(@public_config_file, "w") do |f|
        YAML.dump(@public_config, f)
      end
    end

    private

    # Upgrade path for legacy clients that kept release metadata
    # in config/dev.yml and config/final.yml
    #
    def migrate_legacy_configs
      # We're using blobstore_options as old config marker.
      # Unfortunately old CLI won't tell you to upgrade because it checks
      # for valid blobstore options first, so instead of removing blobstore_options
      # we mark it as deprecated, so new CLI proceeds to migrate while the old one
      # tells you to upgrade.
      if @private_config.has_key?("blobstore_options") &&
          @private_config["blobstore_options"] != "deprecated"
        say("Found legacy dev config file `#{@private_config_file}'".yellow)

        new_private_config = {
          "dev_name" => @private_config["name"],
          "latest_release_filename" => @private_config["latest_release_filename"],

          # Following two options are only needed for older clients
          # to fail gracefully and never actually read by a new client
          "blobstore_options" => "deprecated",
          "min_cli_version" => "0.12"
        }

        @private_config = new_private_config

        File.open(@private_config_file, "w") { |f| YAML.dump(@private_config, f) }
        say("Migrated dev config file format".green)
      end

      if @public_config.has_key?("blobstore_options") &&
          @public_config["blobstore_options"] != "deprecated"
        say("Found legacy config file `#{@public_config_file}'".yellow)

        unless @public_config["blobstore_options"]["provider"] == "atmos" &&
            @public_config["blobstore_options"].has_key?("atmos_options")
          err("Please update your release to the version that uses Atmos blobstore")
        end

        new_public_config = {
          "final_name" => @public_config["name"],
          "min_cli_version" => @public_config["min_cli_version"],
          "blobstore" => {
            "provider" => "atmos",
            "options" => @public_config["blobstore_options"]["atmos_options"]
          },
          "blobstore_options" => "deprecated"
        }

        @public_config = new_public_config

        File.open(@public_config_file, "w") { |f| YAML.dump(@public_config, f) }
        say("Migrated final config file format".green)
      end
    end

    def symbolize_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_sym] = value
        h
      end
    end

  end

end
