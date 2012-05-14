# Copyright (c) 2009-2012 VMware, Inc.

module Bosh; end

module Bosh::Deployer
  class Config

    class << self

      include Helpers

      attr_accessor :logger, :db, :uuid, :resources, :cloud_options,
        :spec_properties, :bosh_ip, :env

      def configure(config)
        plugin = cloud_plugin(config)

        config = deep_merge(load_defaults(plugin), config)

        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        @cloud_options = config["cloud"]
        @net_conf = config["network"]
        @bosh_ip = @net_conf["ip"]
        @resources = config["resources"]
        @env = config["env"]

        @logger = Logger.new(config["logging"]["file"] || STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @logger.formatter = ThreadFormatter.new

        @spec_properties = config["apply_spec"]["properties"]

        @db = Sequel.sqlite

        @db.create_table :vsphere_disk do
          primary_key :id
          column :path, :text
          column :datacenter, :text
          column :datastore, :text
          column :size, :integer
        end

        @db.create_table :instances do
          primary_key :id
          column :name, :text, :unique => true, :null => false
          column :uuid, :text
          column :stemcell_cid, :text
          column :stemcell_name, :text
          column :vm_cid, :text
          column :disk_cid, :text
        end

        Sequel::Model.plugin :validation_helpers

        Bosh::Clouds::Config.configure(self)

        require "deployer/models/instance"

        @cloud_options["properties"]["agent"]["mbus"] ||=
          "http://vcap:b00tstrap@0.0.0.0:6868"

        @disk_model = nil
        @cloud = nil
        @networks = nil
      end

      def cloud
        if @cloud.nil?
          @cloud = Bosh::Clouds::Provider.create(@cloud_options["plugin"],
                                                 @cloud_options["properties"])
        end
        @cloud
      end

      def agent
        uri = URI.parse(@cloud_options["properties"]["agent"]["mbus"])
        uri.host = bosh_ip
        user, password = uri.userinfo.split(":", 2)
        uri.userinfo = nil
        Bosh::Agent::HTTPClient.new(uri.to_s,
                                    { "user" => user,
                                      "password" => password,
                                      "reply_to" => uuid })
      end

      def networks
        @networks ||= {
          "bosh" => {
            "cloud_properties" => @net_conf["cloud_properties"],
            "netmask"          => @net_conf["netmask"],
            "gateway"          => @net_conf["gateway"],
            "ip"               => @net_conf["ip"],
            "dns"              => @net_conf["dns"],
            "type"             => @net_conf["type"],
            "default"          => ["dns", "gateway"]
          }
        }
      end

      private

      def deep_merge(src, dst)
        src.merge(dst) do |key, old, new|
          if new.respond_to?(:blank) && new.blank?
            old
          elsif old.kind_of?(Hash) and new.kind_of?(Hash)
            deep_merge(old, new)
          elsif old.kind_of?(Array) and new.kind_of?(Array)
            old.concat(new).uniq
          else
            new
          end
        end
      end

      def load_defaults(provider)
        file = File.join(File.dirname(File.expand_path(__FILE__)), "../../config/#{provider}_defaults.yml")
        YAML.load_file(file)
      end
    end
  end
end
