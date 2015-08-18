# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  # This class encapsulates the details of handling dev and final releases:
  # also it partitions release metadata between final config (which is
  # under version control) and user dev config.
  class Release
    attr_reader :dir

    def initialize(dir, final = false)
      @dir = dir
      @final = final

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
    [:final_name].each do |attr|
      define_method(attr) do
        @final_config[attr.to_s]
      end

      define_method("#{attr}=".to_sym) do |value|
        @final_config[attr.to_s] = value
      end
    end

    # Check if the deprecated blobstore secret is provided in the private
    # config file
    # @return [Boolean]
    def has_legacy_secret?
      @private_config.has_key?("blobstore_secret")
    end

    def has_blobstore_secret?
      bs = @private_config["blobstore"]

      return false unless @final_config['blobstore']

      # Add special handling for local blobstore which should not need need credentials
      provider = @final_config['blobstore']['provider']
      return true if provider == 'local'

      has_legacy_secret? ||
        has_blobstore_secrets?(bs, "simple", "user", "password") ||
        has_blobstore_secrets?(bs, "dav", "user", "password") ||
        has_blobstore_secrets?(bs, "swift", "rackspace") ||
        has_blobstore_secrets?(bs, "swift", "hp") ||
        has_blobstore_secrets?(bs, "swift", "openstack") ||
        has_blobstore_secrets?(bs, "s3", "access_key_id", "secret_access_key")
    end

    # final.yml
    # ---
    # blobstore:
    #   provider: ...
    #   options:
    #     ...: ...

    # private.yml
    # ---
    # blobstore:
    #   s3:
    #     secret_access_key: ...
    #     access_key_id: ...

    # Picks blobstore client to use with current release.
    #
    # @return [Bosh::Blobstore::Client] blobstore client
    def blobstore
      return @blobstore if @blobstore
      blobstore_config = Marshal.load(Marshal.dump(@final_config["blobstore"]))

      if blobstore_config.nil?
        err("Missing blobstore configuration, please update config/final.yml") if @final
        unless @user_warned
          warning("Missing blobstore configuration, please update config/final.yml before making a final release")
          @user_warned = true
        end
        return nil
      end

      provider = blobstore_config["provider"]
      options  = blobstore_config["options"] || {}

      options = merge_private_data(provider, options)

      opts = Bosh::Common.symbolize_keys(options)
      @blobstore = Bosh::Blobstore::Client.safe_create(provider, opts)

    rescue Bosh::Blobstore::BlobstoreError => e
      err("Cannot initialize blobstore: #{e}")
    end

    def save_config
      write_yaml(@dev_config_file, @dev_config)
      write_yaml(@final_config_file, @final_config)
    end

    private

    def has_blobstore_secrets?(blobstore, name, *keys)
      return false unless blobstore
      return false unless blobstore[name]
      keys.each {|key| return false unless blobstore[name][key]}
      true
    end


    # Extracts private blobstore data from final.yml (i.e. secrets)
    # and merges it into the blobstore options.
    def merge_private_data(provider, options)
      err("Missing blobstore secret configuration, please update config/private.yml") if @final && !has_blobstore_secret?

      bs = @private_config["blobstore"]
      return options unless bs

      if bs[provider].nil? && has_blobstore_secret?
        err("blobstore private provider does not match final provider")
      end

      options.merge(bs[provider] ? bs[provider] : {})
    end

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
        say("Found legacy dev config file `#{@dev_config_file}'".make_yellow)

        new_dev_config = {
          "dev_name" => @dev_config["name"],
          "latest_release_filename" =>
              @dev_config["latest_release_filename"],

          # Following two options are only needed for older clients
          # to fail gracefully and never actually read by a new client
          "blobstore_options" => "deprecated",
        }

        @dev_config = new_dev_config

        File.open(@dev_config_file, "w") do |f|
          Psych.dump(@dev_config, f)
        end
        say("Migrated dev config file format".make_green)
      end

    end

    def load_config(file)
      if File.exists?(file)
        load_yaml_file(file)
      else
        {}
      end
    end

    def write_yaml(file, hash)
      unless hash == load_config(file)
        File.open(file, "w+") do |f|
          Psych.dump(hash, f)
        end
      end
    end

  end

end
