require 'bosh/dev/vsphere'
require 'bosh/dev/bat/deployment_manifest'

module Bosh::Dev::VSphere
  class BatDeploymentManifest < Bosh::Dev::Bat::DeploymentManifest

    def initialize(*var)
      super(*var)
      @net_type = 'manual'
    end

    def validate
      unless net_type == 'manual'
        raise "Invalid network type '#{net_type}' - VSphere requires manual networking"
      end

      super
    end

    def schema
      new_schema = super

      new_schema.schemas['cpi'] = value_schema('vsphere')

      # only has one network, named 'static'
      network_schema = new_schema.schemas['properties'].schemas['networks'].elem_schema.schemas
      network_schema['name'] = value_schema('static')
      network_schema['vlan'] = string_schema

      new_schema
    end
  end
end
