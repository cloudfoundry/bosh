require 'bosh/dev/openstack'
require 'bosh/dev/bat/deployment_manifest'
require 'membrane'

module Bosh::Dev::Openstack
  class BatDeploymentManifest < Bosh::Dev::Bat::DeploymentManifest

    def schema
      new_schema = super

      new_schema.schemas['cpi'] = value_schema('openstack')

      properties = new_schema.schemas['properties']

      # properties.vip is required
      properties.schemas['vip'] = string_schema

      # properties.flavor_with_no_ephemeral_disk is required
      properties.schemas['flavor_with_no_ephemeral_disk'] = string_schema

      # properties.key_name is optional
      properties.schemas['key_name'] = string_schema
      properties.optional_keys << 'key_name'

      network_schema = new_schema.schemas['properties'].schemas['networks'].elem_schema.schemas
      cloud_properties = strict_record({
        'net_id' => string_schema,
        'security_groups' => list_schema(string_schema),
      })
      if net_type == 'dynamic'
        cloud_properties.optional_keys << 'net_id'
      end
      network_schema['cloud_properties'] = cloud_properties

      new_schema
    end

    private

    def optional(key)
      Membrane::SchemaParser::Dsl::OptionalKeyMarker.new(key)
    end

  end
end
