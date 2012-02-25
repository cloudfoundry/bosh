module Bosh; end

module Bosh::Deployer
  class Config

    class << self

      attr_accessor :logger, :db, :uuid, :resources, :cloud_options, :spec_properties

      def configure(config)
        if config["cloud"].nil?
          raise ConfigError, "No cloud properties defined"
        end
        if config["cloud"]["plugin"].nil?
          raise ConfigError, "No cloud plugin defined"
        end

        config = deep_merge(load_defaults(config["cloud"]["plugin"]), config)

        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        @cloud_options = config["cloud"]
        @net_conf = config["network"]
        @resources = config["resources"]

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
          "http://vcap:b00tstrap@#{@net_conf["ip"]}:6868"
      end

      def disk_model
        if @disk_model.nil?
          case @cloud_options["plugin"]
          when "vsphere"
            require "cloud/vsphere"
            @disk_model = VSphereCloud::Models::Disk
          else
          end
        end
        @disk_model
      end

      def cloud
        if @cloud.nil?
          @cloud = Bosh::Clouds::Provider.create(@cloud_options["plugin"],
                                                 @cloud_options["properties"])
        end
        @cloud
      end

      def agent
        if @agent.nil?
          uri = URI.parse(@cloud_options["properties"]["agent"]["mbus"])
          user, password = uri.userinfo.split(":", 2)
          uri.userinfo = nil
          @agent = Bosh::Agent::HTTPClient.new(uri.to_s,
                                               { "user" => user,
                                                 "password" => password })
        end
        @agent
      end

      def networks
        @networks ||= {
          "bosh" => {
            "cloud_properties" => @net_conf["cloud_properties"],
            "netmask"          => @net_conf["netmask"],
            "gateway"          => @net_conf["gateway"],
            "ip"               => @net_conf["ip"],
            "dns"              => @net_conf["dns"],
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
