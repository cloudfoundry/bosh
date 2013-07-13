# Copyright (c) 2009-2012 VMware, Inc.

module VSphereCloud

  # vSphere CPI Config
  class Config

    # Membrane schema for the provided config.
    @schema = Membrane::SchemaParser.parse do
        {
            "agent" => dict(String, Object), # passthrough to the agent
            optional("cpi_log") => String,
            optional("soap_log") => String,
            optional("mem_overcommit_ratio") => Numeric,
            optional("copy_disks") => bool,
            "vcenters" => [{
              "host" => String,
              "user" => String,
              "password" => String,
              "datacenters" => [{
                "name" => String,
                "vm_folder" => String,
                "template_folder" => String,
                optional("use_sub_folder") => bool,
                "disk_path" => String,
                "datastore_pattern" => String,
                "persistent_datastore_pattern" => String,
                optional("allow_mixed_datastores") => bool,
                "clusters" => [enum(String,
                                   dict(String, {"resource_pool" => String}))]
              }]
            }]
        }
    end

    # vCenter config.
    class VCenterConfig

      # @!attribute host
      #   @return [String] vCenter host.
      attr_accessor :host

      # @!attribute user
      #   @return [String] vCenter user.
      attr_accessor :user

      # @!attribute password
      #   @return [String] vCenter password.
      attr_accessor :password

      # @!attribute datacenters
      #   @return [Hash<String, DatacenterConfig>] child datacenters.
      attr_accessor :datacenters

      # Creates a new vCenter Config model from parsed YAML.
      #
      # @param [Hash] config parsed YAML.
      def initialize(config)
        @host = config["host"]
        @user = config["user"]
        @password = config["password"]
        @datacenters = {}

        unless config["datacenters"].size == 1
          raise "vSphere CPI only supports a single datacenter."
        end

        config["datacenters"].each do |dc|
          dc_config = DatacenterConfig.new(dc)
          @datacenters[dc_config.name] = dc_config
        end
      end
    end

    # Folder config.
    class FolderConfig
      # @!attribute vm
      #   @return [String] vm folder path.
      attr_accessor :vm

      # @!attribute template
      #   @return [String] template/stemcell folder path.
      attr_accessor :template

      # @!attribute shared
      #   @return [true, false] boolean indicating shared folders, so an
      #     additional namespace should be used.
      attr_accessor :shared
    end

    # Datastore config.
    class DatastoreConfig

      # @!attribute ephemeral_pattern
      #   @return [Regexp] regexp pattern for ephemeral datastores.
      attr_accessor :ephemeral_pattern

      # @!attribute persistent_pattern
      #   @return [Regexp] regexp pattern for persistent datastores.
      attr_accessor :persistent_pattern

      # @!attribute disk_path
      #   @return [String] VMDK datastore path.
      attr_accessor :disk_path

      # @!attribute allow_mixed
      #   @return [true, false] boolean indicating whether persistent and
      #     ephemeral datastores can overlap..
      attr_accessor :allow_mixed
    end

    # Datacenter config.
    class DatacenterConfig

      # @!attribute name
      #   @return [String] datacenter name.
      attr_accessor :name

      # @!attribute folders
      #   @return [FolderConfig] folder config.
      attr_accessor :folders

      # @!attribute datastores
      #   @return [DatastoreConfig] datastore config.
      attr_accessor :datastores

      # @!attribute clusters
      #   @return [Hash<String, ClusterConfig>] child clusters.
      attr_accessor :clusters

      # Creates a new Datacenter Config model from parsed YAML.
      #
      # @param [Hash] config parsed YAML.
      def initialize(config)
        @name = config["name"]

        @folders = FolderConfig.new
        @folders.template = config["template_folder"]
        @folders.vm = config["vm_folder"]
        @folders.shared = !!config["use_sub_folder"]

        @datastores = DatastoreConfig.new
        @datastores.ephemeral_pattern = Regexp.new(config["datastore_pattern"])
        @datastores.persistent_pattern = Regexp.new(
            config["persistent_datastore_pattern"])
        @datastores.disk_path = config["disk_path"]
        @datastores.allow_mixed = !!config["allow_mixed_datastores"]

        @clusters = {}
        config["clusters"].each do |cluster|
          cluster_config = ClusterConfig.new(cluster)
          @clusters[cluster_config.name] = cluster_config
        end

        if @clusters.any? { |_, cluster| cluster.resource_pool }
          @folders.shared = true
        end
      end
    end

    # Cluster config.
    class ClusterConfig

      # @!attribute name
      #   @return [String] cluster name.
      attr_accessor :name

      # @!attribute resource_pool
      #   @return [String?] optional resource pool to use instead of root.
      attr_accessor :resource_pool

      # Creates a new Cluster Config model from parsed YAML.
      #
      # @param [Hash] config parsed YAML.
      def initialize(config)
        case config
          when String
            @name = config
          else
            @name = config.keys.first
            @resource_pool = config[@name]["resource_pool"]
        end
      end
    end

    class << self

      CONFIG_OPTIONS = [
          :logger,
          :client,
          :rest_client,
          :agent,
          :copy_disks,
          :vcenter,
          :mem_overcommit,
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      # Clear all of the properties.
      #
      # Used by unit tests.
      # @return [void]
      def clear
        CONFIG_OPTIONS.each do |option|
          self.instance_variable_set("@#{option}".to_sym, nil)
        end
      end

      # Setup the Config context based on the parsed YAML.
      #
      # @return [void]
      def configure(config)
        @logger = Bosh::Clouds::Config.logger
        @schema.validate(config)
        @agent = config["agent"]

        unless config["vcenters"].size == 1
          raise "vSphere CPI only supports a single vCenter."
        end
        @vcenter = VCenterConfig.new(config["vcenters"].first)

        @client = Client.new("https://#{@vcenter.host}/sdk/vimService", {
            "soap_log" => config["soap_log"] || config["cpi_log"]
        })
        @client.login(@vcenter.user, @vcenter.password, "en")

        @rest_client = HTTPClient.new
        @rest_client.send_timeout = 14400 # 4 hours, for stemcell uploads
        @rest_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

        # HACK: read the session from the SOAP client so we don't leak sessions
        # when using the REST client
        cookie_str = @client.stub.cookie
        @rest_client.cookie_manager.parse(
            cookie_str, URI.parse("https://#{@vcenter.host}"))

        if config["mem_overcommit_ratio"]
          @mem_overcommit = config["mem_overcommit_ratio"].to_f
        else
          @mem_overcommit = 1.0
        end

        @copy_disks = !!config["copy_disks"]
      end
    end
  end
end
