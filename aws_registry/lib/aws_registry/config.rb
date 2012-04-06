# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry

  class << self

    AWS_MAX_RETRIES = 2
    AWS_EC2_ENDPOINT = "ec2.amazonaws.com"

    attr_accessor :logger
    attr_accessor :http_port
    attr_accessor :http_user
    attr_accessor :http_password
    attr_accessor :db

    attr_writer :ec2

    def configure(config)
      validate_config(config)

      @logger ||= Logger.new(config["logfile"] || STDOUT)

      if config["loglevel"].kind_of?(String)
        @logger.level = Logger.const_get(config["loglevel"].upcase)
      end

      @http_port = config["http"]["port"]
      @http_user = config["http"]["user"]
      @http_password = config["http"]["password"]

      @aws = config["aws"]

      @aws_options = {
        :access_key_id => @aws["access_key_id"],
        :secret_access_key => @aws["secret_access_key"],
        :max_retries => @aws["max_retries"] || AWS_MAX_RETRIES,
        :ec2_endpoint => @aws["ec2_endpoint"] || AWS_EC2_ENDPOINT,
        :logger => @logger
      }

      @db = connect_db(config["db"])
    end

    def ec2
      @ec2 ||= AWS::EC2.new(@aws_options)
    end

    def connect_db(db_config)
      connection_options = {
        :max_connections => db_config["max_connections"],
        :pool_timeout => db_config["pool_timeout"]
      }

      db = Sequel.connect(db_config["database"], connection_options)
      db.logger = @logger
      db.sql_log_level = :debug
      db
    end

    def validate_config(config)
      unless config.is_a?(Hash)
        raise ConfigError, "Invalid config format, Hash expected, " \
                           "#{config.class} given"
      end

      unless config.has_key?("http") && config["http"].is_a?(Hash)
        raise ConfigError, "HTTP configuration is missing from " \
                           "config file"
      end

      unless config.has_key?("db") && config["db"].is_a?(Hash)
        raise ConfigError, "Database configuration is missing from " \
                           "config file"
      end

      unless config.has_key?("aws") && config["aws"].is_a?(Hash)
        raise ConfigError, "AWS configuration is missing from " \
                           "config file"
      end
    end

  end

end
