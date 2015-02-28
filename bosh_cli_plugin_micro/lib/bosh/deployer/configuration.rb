require 'bosh/deployer/models/instance'
require 'bosh/deployer/infrastructure_defaults'
require 'mono_logger'

module Bosh::Deployer
  class Configuration
    attr_accessor :logger, :db, :uuid, :resources, :cloud_options,
                  :spec_properties, :agent_properties, :env, :name, :net_conf

    attr_reader :base_dir

    # rubocop:disable MethodLength
    def configure(config)
      plugin = config['cloud']['plugin']
      config = InfrastructureDefaults.merge_for(plugin, config)

      @base_dir = config['dir']
      FileUtils.mkdir_p(@base_dir)

      @name = config['name']
      @cloud_options = config['cloud']
      @net_conf = config['network']
      @resources = config['resources']
      @env = config['env']
      @deployment_network = config['deployment_network']

      log_io = config['logging']['file'] || STDOUT
      if log_io.is_a?(String)
        log_io = File.open(log_io, (File::WRONLY | File::APPEND | File::CREAT))
      end
      @logger = MonoLogger.new(log_io)
      @logger.level = MonoLogger.const_get(config['logging']['level'].upcase)
      @logger.formatter = ThreadFormatter.new

      apply_spec = config['apply_spec']
      @spec_properties = apply_spec['properties']
      @agent_properties = apply_spec['agent']

      @db = Sequel.sqlite

      migrate_cpi

      @db.create_table :instances do
        primary_key :id
        column :name, :text, unique: true, null: false
        column :uuid, :text
        column :stemcell_cid, :text
        column :stemcell_sha1, :text
        column :stemcell_name, :text
        column :config_sha1, :text
        column :vm_cid, :text
        column :disk_cid, :text
      end

      Sequel::Model.plugin :validation_helpers

      Bosh::Clouds::Config.configure(self)
      Models.define_instance_from_table(db[:instances])

      @cloud_options['properties']['agent']['mbus'] ||=
        'https://vcap:b00tstrap@0.0.0.0:6868'

      @cloud = nil
      @networks = nil
      @uuid = SecureRandom.uuid

      self
    end
    # rubocop:enable MethodLength

    def cloud
      if @cloud.nil?
        @cloud = Bosh::Clouds::Provider.create(@cloud_options, @uuid)
      end
      @cloud
    end

    def agent_url
      @cloud_options['properties']['agent']['mbus']
    end

    def networks
      @networks ||= {
        'bosh' => {
          'cloud_properties' => @net_conf['cloud_properties'],
          'netmask' => @net_conf['netmask'],
          'gateway' => @net_conf['gateway'],
          'ip' => @net_conf['ip'],
          'dns' => @net_conf['dns'],
          'type' => @net_conf['type'],
          'default' => %w(dns gateway)
        }
      }.merge(vip_network).merge(deployment_network)
    end

    def task_checkpoint
      # Bosh::Clouds::Config (bosh_cli >= 0.5.1) delegates task_checkpoint
      # method to periodically check if director task is cancelled,
      # so we need to define a void method in Bosh::Deployer::Config to avoid
      # NoMethodError exceptions.
    end

    def agent_services_ip
      if net_conf['type'] == 'dynamic'
        net_conf['vip']
      elsif @deployment_network
        @deployment_network['ip']
      else
        net_conf['ip']
      end
    end

    def client_services_ip
      net_conf['vip'] || net_conf['ip']
    end

    def internal_services_ip
      '127.0.0.1'
    end

    def cpi_task_log
      cloud_options.fetch('properties', {})['cpi_log']
    end

    private

    def vip_network
      return {} unless @net_conf['vip']
      {
        'vip' => {
          'ip' => @net_conf['vip'],
          'type' => 'vip',
          'cloud_properties' => @net_conf['cloud_properties']
        }
      }
    end

    def deployment_network
      return {} unless @deployment_network
      {
        'deployment' => @deployment_network
      }
    end

    def migrate_cpi
      cpi = @cloud_options['plugin']
      require_path = File.join('cloud', cpi)
      cpi_path = $LOAD_PATH.find { |p| File.exist?(File.join(p, require_path)) }
      migrations = File.expand_path('../db/migrations', cpi_path)

      if File.directory?(migrations)
        Sequel.extension :migration
        Sequel::TimestampMigrator.new(@db, migrations, table: "#{cpi}_cpi_schema").run
      end
    end
  end
end
