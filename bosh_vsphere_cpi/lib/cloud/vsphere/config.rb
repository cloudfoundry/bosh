require 'cloud/vsphere/cluster_config'

module VSphereCloud
  class Config
    def self.build(config_hash)
      config = new(config_hash)
      config.validate
      config
    end

    def initialize(config_hash)
      @config = config_hash
      @vcenter_host = nil
      @vcenter_user = nil
      @vcenter_password = nil
      @rest_client = nil
      @default_overcommit_ratio = 1.0

      @is_validated = false
    end

    def validate
      return true if @is_validated

      unless config['vcenters'].size == 1
        raise 'vSphere CPI only supports a single vCenter'
      end

      unless config['vcenters'].first['datacenters'].size ==1
        raise 'vSphere CPI only supports a single datacenter'
      end

      validate_schema

      @is_validated = true
    end

    def logger
      @logger ||= Bosh::Clouds::Config.logger
    end

    def client
      unless @client
        @client = Client.new("https://#{vcenter['host']}/sdk/vimService", {
          'soap_log' => config['soap_log'] || config['cpi_log']
        })

        @client.login(vcenter['user'], vcenter['password'], 'en')
      end

      @client
    end

    def rest_client
      unless @rest_client
        @rest_client = HTTPClient.new
        @rest_client.send_timeout = 14400 # 4 hours, for stemcell uploads
        @rest_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

        # HACK: read the session from the SOAP client so we don't leak sessions
        # when using the REST client
        cookie_str = client.soap_stub.cookie
        @rest_client.cookie_manager.parse(cookie_str, URI.parse("https://#{vcenter_host}"))
      end

      @rest_client
    end

    def mem_overcommit
      config.fetch('mem_overcommit_ratio', @default_overcommit_ratio)
    end

    def copy_disks
      !!config['copy_disks']
    end

    def agent
      config['agent']
    end

    def vcenter_host
      vcenter['host']
    end

    def vcenter_user
      vcenter['user']
    end

    def vcenter_password
      vcenter['password']
    end

    def datacenter_name
      vcenter_datacenter['name']
    end

    def datacenter_vm_folder
      vcenter_datacenter['vm_folder']
    end

    def datacenter_template_folder
      vcenter_datacenter['template_folder']
    end

    def datacenter_disk_path
      vcenter_datacenter['disk_path']
    end

    def datacenter_datastore_pattern
      Regexp.new(vcenter_datacenter['datastore_pattern'])
    end

    def datacenter_persistent_datastore_pattern
      Regexp.new(vcenter_datacenter['persistent_datastore_pattern'])
    end

    def datacenter_clusters
      @cluster_objs ||= cluster_objs
    end

    def datacenter_allow_mixed_datastores
      !!vcenter_datacenter['allow_mixed_datastores']
    end

    def datacenter_use_sub_folder
      datacenter_clusters.any? { |_, cluster| cluster.resource_pool } ||
        !!vcenter_datacenter['use_sub_folder']
    end

    private

    attr_reader :config

    def is_validated?
      raise 'Configuration has not been validated' unless @is_validated
    end

    def vcenter
      config['vcenters'].first
    end

    def vcenter_datacenter
      vcenter['datacenters'].first
    end

    def validate_schema
      # Membrane schema for the provided config.
      schema = Membrane::SchemaParser.parse do
        {
          'agent' => dict(String, Object), # passthrough to the agent
          optional('cpi_log') => String,
          optional('soap_log') => String,
          optional('mem_overcommit_ratio') => Numeric,
          optional('copy_disks') => bool,
          'vcenters' => [{
                           'host' => String,
                           'user' => String,
                           'password' => String,
                           'datacenters' => [{
                                               'name' => String,
                                               'vm_folder' => String,
                                               'template_folder' => String,
                                               optional('use_sub_folder') => bool,
                                               'disk_path' => String,
                                               'datastore_pattern' => String,
                                               'persistent_datastore_pattern' => String,
                                               optional('allow_mixed_datastores') => bool,
                                               'clusters' => [enum(String,
                                                                   dict(String, { 'resource_pool' => String }))]
                                             }]
                         }]
        }
      end

      schema.validate(config)
    end

    def cluster_objs
      cluster_objs = {}
      vcenter_datacenter['clusters'].each do |cluster|
        if cluster.is_a?(Hash)
          name = cluster.keys.first
          cluster_objs[name] = ClusterConfig.new(name, cluster[name])
        else
          cluster_objs[cluster] = ClusterConfig.new(cluster, {})
        end
      end
      cluster_objs
    end
  end

end
