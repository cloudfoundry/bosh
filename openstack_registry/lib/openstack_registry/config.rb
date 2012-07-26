# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::OpenstackRegistry

  class << self

    attr_accessor :logger
    attr_accessor :http_port
    attr_accessor :http_user
    attr_accessor :http_password
    attr_accessor :db

    attr_writer :openstack

    def configure(config)
      validate_config(config)

      @logger ||= Logger.new(config["logfile"] || STDOUT)

      if config["loglevel"].kind_of?(String)
        @logger.level = Logger.const_get(config["loglevel"].upcase)
      end

      @http_port = config["http"]["port"]
      @http_user = config["http"]["user"]
      @http_password = config["http"]["password"]

      @openstack_properties = config["openstack"]

      @openstack_options = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties["auth_url"],
        :openstack_username => @openstack_properties["username"],
        :openstack_api_key => @openstack_properties["api_key"],
        :openstack_tenant => @openstack_properties["tenant"]
      }

      @db = connect_db(config["db"])
    end

    def openstack
      openstack ||= Fog::Compute.new(@openstack_options)
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

      unless config.has_key?("openstack") && config["openstack"].is_a?(Hash)
        raise ConfigError, "OpenStack configuration is missing from " \
                           "config file"
      end
    end

  end

end
