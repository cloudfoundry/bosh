# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class Config
    VALID_ID = /^[-a-z0-9_.]+$/i

    class << self
      # @return [Hash<String,Bosh::Cli::CommandDefinition>] Available commands
      attr_reader :commands

      # @return [Boolean] Should CLI output be colorized?
      attr_accessor :colorize

      # @return [IO] Where output goes
      attr_accessor :output

      # @return [Boolean] Is CLI being used interactively?
      attr_accessor :interactive

      # @return [Integer] CLI polling interval
      attr_accessor :poll_interval

      # @return [Integer] CLI max parallel downloads
      attr_accessor :max_parallel_downloads
    end

    @commands = {}
    @colorize = nil
    @output = nil
    @interactive = false

    # Register command with BOSH CLI
    # @param [Bosh::Cli::CommandDefinition] command
    # @return [void]
    def self.register_command(command)
      if @commands.has_key?(command.usage)
        raise CliError, "Duplicate command `#{command.usage}'"
      end
      @commands[command.usage] = command
    end

    def initialize(filename, work_dir = Dir.pwd)
      @filename = File.expand_path(filename || Bosh::Cli::DEFAULT_CONFIG_PATH)
      @work_dir = work_dir

      unless File.exists?(@filename)
        File.open(@filename, "w") { |f| Psych.dump({}, f) }
        File.chmod(0600, @filename)
      end

      @config_file = load_yaml_file(@filename, nil)

      unless @config_file.is_a?(Hash)
        @config_file = {} # Just ignore it if it's malformed
      end

    rescue SystemCallError => e
      raise ConfigError, "Cannot read config file: #{e.message}"
    end

    # @return [Hash] Director credentials
    def credentials_for(target)
      if @config_file["auth"].is_a?(Hash) && @config_file["auth"][target]
        @config_file["auth"][target]
      else
        {
          "username" => nil,
          "password" => nil
        }
      end
    end

    def set_credentials(target, credentials)
      @config_file["auth"] ||= {}
      @config_file["auth"][target] = credentials
    end

    def set_alias(category, alias_name, value)
      @config_file["aliases"] ||= {}
      @config_file["aliases"][category.to_s] ||= {}
      @config_file["aliases"][category.to_s][alias_name] = value
    end

    def aliases(category)
      if @config_file.has_key?("aliases") && @config_file["aliases"].is_a?(Hash)
        @config_file["aliases"][category.to_s]
      else
        nil
      end
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

    # @param [String] target Target director url
    # @return [String] Username associated with target
    def username(target)
      credentials_for(target)["username"]
    end

    # @param [String] target Target director url
    # @return [String] Password associated with target
    def password(target)
      credentials_for(target)["password"]
    end

    # @param [String] target Target director url
    # @return [String] Token associated with target
    def access_token(target)
      credentials_for(target)["access_token"]
    end

    # @param [String] target Target director url
    # @return [String] Refresh token associated with target
    def refresh_token(target)
      credentials_for(target)["refresh_token"]
    end

    # Deployment used to be a string that was only stored for your
    # current target. As soon as you switched targets, the deployment
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
      raise MissingTarget, "Must have a target set" if target.nil?
      @config_file["deployment"] = {} if is_old_deployment_config?
      @config_file["deployment"] ||= {}
      @config_file["deployment"][target] = deployment_file_path
    end

    def target
      read(:target, false)
    end

    def target=(value)
      write_global(:target, value)
    end

    def target_name
      read(:target_name, false)
    end

    def target_name=(value)
      write_global(:target_name, value)
    end

    def target_version
      read(:target_version, false)
    end

    def target_version=(value)
      write_global(:target_version, value)
    end

    def release
      read(:release, false)
    end

    def release=(value)
      write_global(:release, value)
    end

    def target_uuid
      read(:target_uuid, false)
    end

    def target_uuid=(value)
      write_global(:target_uuid, value)
    end

    def ca_cert(for_target=nil)
      if for_target
        return @config_file.fetch('ca_cert', {}).fetch(for_target, nil)
      end

      return nil if target.nil?

      @config_file.fetch('ca_cert', {}).fetch(target, nil)
    end


    def save_ca_cert_path(cert_path, for_target=nil)
      expanded_path = cert_path ? File.expand_path(cert_path) : nil
      cert_target = for_target || target
      @config_file['ca_cert'] ||= {}
      @config_file['ca_cert'][cert_target] = expanded_path

      expanded_path
    end

    # Read the max parallel downloads configuration.
    #
    # @return [Integer] The maximum number of parallel downloads
    def max_parallel_downloads
      self.class.max_parallel_downloads || @config_file.fetch("max_parallel_downloads", 1)
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
        Psych.dump(@config_file, f)
      end

    rescue SystemCallError => e
      raise ConfigError, e.message
    end

    attr_reader :filename
  end
end
