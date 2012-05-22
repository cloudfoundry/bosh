# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class Config
    VALID_ID = /^[-a-z0-9_.]+$/i

    class << self
      attr_accessor :colorize
      attr_accessor :output
      attr_accessor :interactive
      attr_accessor :cache
    end

    def initialize(filename, work_dir = Dir.pwd)
      @filename = File.expand_path(filename)
      @work_dir = work_dir

      unless File.exists?(@filename)
        File.open(@filename, "w") { |f| YAML.dump({}, f) }
        File.chmod(0600, @filename)
      end

      @config_file = load_yaml_file(@filename, nil)

      unless @config_file.is_a?(Hash)
        @config_file = { } # Just ignore it if it's malformed
      end

    rescue SystemCallError => e
      raise ConfigError, "Cannot read config file: #{e.message}"
    end

    def auth
      if @config_file.has_key?("auth") && @config_file["auth"].is_a?(Hash)
        @config_file["auth"][target]
      else
        nil
      end
    end

    def set_credentials(target, username, password)
      @config_file["auth"] ||= { }
      @config_file["auth"][target] = { "username" => username,
                                       "password" => password }
    end

    def set_alias(category, alias_name, value)
      @config_file["aliases"] ||= { }
      @config_file["aliases"][category.to_s] ||= { }
      @config_file["aliases"][category.to_s][alias_name] = value
    end

    def resolve_alias(category, alias_name)
      category = category.to_s

      if @config_file.has_key?("aliases") &&
          @config_file["aliases"].is_a?(Hash) &&
          @config_file["aliases"].has_key?(category) &&
          @config_file["aliases"][category].is_a?(Hash) &&
          !@config_file["aliases"][category][alias_name].blank?
        @config_file["aliases"][category][alias_name].to_s
      else
        nil
      end
    end

    def username
      auth ? auth["username"] : nil
    end

    def password
      auth ? auth["password"] : nil
    end

    # Deployment used to be a string that was only stored for your
    # current target.  As soon as you switched targets, the deployment
    # was erased. If the user has the old config we convert it to the
    # new config.
    #
    # @return [Boolean] Whether config is using the old deployment format.
    def is_old_deployment_config?
      @config_file["deployment"].is_a?(String)
    end

    # Read the deployment configuration.  Return the deployment for the
    # current target.
    #
    # @return [String?] The deployment path for the current target.
    def deployment
      return nil if target.nil?
      if @config_file.has_key?("deployment")
        if is_old_deployment_config?
          set_deployment(@config_file["deployment"])
          save
        end
        if @config_file["deployment"].is_a?(Hash)
          return @config_file["deployment"][target]
        end
      end
    end

    # Sets the deployment file for the current target. If the deployment is
    # the old deployment configuration, it will turn it into the format.
    #
    # @raise [MissingTarget] If there is no target set.
    # @param [String] deployment_file_path The string path to the
    #     deployment file.
    def set_deployment(deployment_file_path)
      raise MissingTarget, "Must have a target set." if target.nil?
      @config_file["deployment"] = { } if is_old_deployment_config?
      @config_file["deployment"] ||= { }
      @config_file["deployment"][target] = deployment_file_path
    end

    [:target, :target_name, :target_version, :release,
     :target_uuid, :status_timeout].each do |attr|
      define_method attr do
        read(attr, false)
      end

      define_method "#{attr}=" do |value|
        write_global(attr, value)
      end
    end

    def read(attr, try_local_first = true)
      attr = attr.to_s
      if try_local_first && @config_file[@work_dir].is_a?(Hash) &&
          @config_file[@work_dir].has_key?(attr)
        @config_file[@work_dir][attr]
      else
        @config_file[attr]
      end
    end

    def write(attr, value)
      @config_file[@work_dir] ||= {}
      @config_file[@work_dir][attr.to_s] = value
    end

    def write_global(attr, value)
      @config_file[attr.to_s] = value
    end

    def save
      File.open(@filename, "w") do |f|
        YAML.dump(@config_file, f)
      end

    rescue SystemCallError => e
      raise ConfigError, e.message
    end

  end
end
