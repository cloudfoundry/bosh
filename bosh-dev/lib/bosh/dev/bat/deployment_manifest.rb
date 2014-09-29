require 'bosh/dev/bat'
require 'bosh/dev/writable_manifest'
require 'membrane'

module Bosh::Dev::Bat
  class DeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename
    attr_accessor :director_uuid, :net_type, :stemcell

    def self.load_from_file(bat_deployment_config_path)
      config_contents = File.read(bat_deployment_config_path)
      load(config_contents)
    end

    def self.load(bat_deployment_config_yaml)
      manifest_hash = YAML.load(bat_deployment_config_yaml)
      puts manifest_hash.to_yaml
      new(manifest_hash)
    rescue SyntaxError => e
      puts "Failed to load BAT deployment config yaml:\n#{bat_deployment_config_yaml}"
      raise e
    end

    def initialize(manifest_hash)
      @manifest_hash = manifest_hash
      @filename = 'bat.yml'
      @net_type = 'dynamic'
    end

    def stemcell=(stemcell_archive)
      @stemcell = stemcell_archive
      @manifest_hash['properties']['stemcell'] = {
        'name' => stemcell_archive.name,
        'version' => stemcell_archive.version
      }
    end

    def to_h
      # uuid is lazy-loaded after targetting the director
      @manifest_hash['properties']['uuid'] = director_uuid.value if director_uuid

      @manifest_hash
    end

    def ==(other)
      to_h == other.to_h
    end

    def validate
      schema.validate(@manifest_hash)
    end

    def schema
      new_schema = strict_record({
        'cpi' => string_schema,
        'properties' => strict_record({
          'pool_size' => integer_schema,
          'instances' => integer_schema,
          'networks' => list_schema(
            strict_record({
              'name' => string_schema,
              'type' => value_schema(net_type),
              'static_ip' => string_schema,
            })
          )
        })
      })

      if net_type == 'manual'
        properties = new_schema.schemas['properties'].schemas

        # used for testing network reconfigure
        properties['second_static_ip'] = string_schema

        network_schema = properties['networks'].elem_schema.schemas
        network_schema['cidr'] = string_schema
        network_schema['reserved'] = list_schema(string_schema)
        network_schema['static'] = list_schema(string_schema)
        network_schema['gateway'] = string_schema
      end

      unless stemcell.nil?
        new_schema.schemas['properties'].schemas['stemcell'] = strict_record({
          'name' => string_schema,
          'version' => enum_schema(string_schema, integer_schema),
        })
      end

      new_schema
    end

    private

    def strict_record(hash)
      Membrane::Schemas::Record.new(hash, optional_keys=[], strict_checking=true)
    end

    def string_schema
      Membrane::Schemas::Class.new(String)
    end

    def integer_schema
      Membrane::Schemas::Class.new(Integer)
    end

    def value_schema(value)
      Membrane::Schemas::Value.new(value)
    end

    def list_schema(list)
      Membrane::Schemas::List.new(list)
    end

    def enum_schema(*schemas)
      Membrane::Schemas::Enum.new(*schemas)
    end
  end
end
