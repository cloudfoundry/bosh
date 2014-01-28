module Bosh::Deployer
  class Configuration
    attr_accessor :logger, :db, :uuid, :resources, :cloud_options,
                  :spec_properties, :agent_properties, :bosh_ip, :env, :name, :net_conf

    # rubocop:disable MethodLength
    def configure(config)
      plugin = config['cloud']['plugin']

      config = deep_merge(load_defaults(plugin), config)

      @base_dir = config['dir']
      FileUtils.mkdir_p(@base_dir)

      @name = config['name']
      @cloud_options = config['cloud']
      @net_conf = config['network']
      @bosh_ip = @net_conf['ip']
      @resources = config['resources']
      @env = config['env']

      @logger = Logger.new(config['logging']['file'] || STDOUT)
      @logger.level = Logger.const_get(config['logging']['level'].upcase)
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

      require 'bosh/deployer/models/instance'

      @cloud_options['properties']['agent']['mbus'] ||=
        'https://vcap:b00tstrap@0.0.0.0:6868'

      @disk_model = nil
      @cloud = nil
      @networks = nil
    end
    # rubocop:enable MethodLength

    def cloud
      if @cloud.nil?
        @cloud = Bosh::Clouds::Provider.create(
          @cloud_options['plugin'], @cloud_options['properties'])
      end
      @cloud
    end

    def agent
      uri = URI.parse(agent_url)
      user, password = uri.userinfo.split(':', 2)
      uri.userinfo = nil
      uri.host = bosh_ip
      Bosh::Agent::HTTPClient.new(uri.to_s, {
        'user' => user,
        'password' => password,
        'reply_to' => uuid,
      })
    end

    def agent_url
      @cloud_options['properties']['agent']['mbus']
    end

    def networks
      return @networks if @networks

      @networks = {
        'bosh' => {
          'cloud_properties' => @net_conf['cloud_properties'],
          'netmask' => @net_conf['netmask'],
          'gateway' => @net_conf['gateway'],
          'ip' => @net_conf['ip'],
          'dns' => @net_conf['dns'],
          'type' => @net_conf['type'],
          'default' => %w(dns gateway)
        }
      }
      if @net_conf['vip']
        @networks['vip'] = {
          'ip' => @net_conf['vip'],
          'type' => 'vip',
          'cloud_properties' => {}
        }
      end

      @networks
    end

    def task_checkpoint
      # Bosh::Clouds::Config (bosh_cli >= 0.5.1) delegates task_checkpoint
      # method to periodically check if director task is cancelled,
      # so we need to define a void method in Bosh::Deployer::Config to avoid
      # NoMethodError exceptions.
    end

    private

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

    def deep_merge(src, dst)
      src.merge(dst) do |key, old, new|
        if new.respond_to?(:blank) && new.blank?
          old
        elsif old.kind_of?(Hash) && new.kind_of?(Hash)
          deep_merge(old, new)
        elsif old.kind_of?(Array) && new.kind_of?(Array)
          old.concat(new).uniq
        else
          new
        end
      end
    end

    def load_defaults(provider)
      file = File.expand_path("../../../../config/#{provider}_defaults.yml", __FILE__)
      Psych.load_file(file)
    end
  end
end
