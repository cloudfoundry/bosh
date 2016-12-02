require 'json'
require 'yaml'

Sequel.migration do
  change do
    self[:instances].all do |instance|
      instance_spec_json = instance[:spec_json]
      next if instance_spec_json == nil || instance_spec_json == ""

      spec_json = JSON.parse(instance_spec_json)
      deployment = self[:deployments].where(id: instance[:deployment_id]).first

      deployment_manifest_yml = deployment[:manifest]
      next if deployment_manifest_yml == nil || deployment_manifest_yml == ""

      manifest_hash = YAML.load(deployment_manifest_yml)

      groups = manifest_hash['jobs'] || manifest_hash['instance_groups']
      next if groups == nil

      group = groups.find { |instance_group| instance_group['name'] == instance[:job] }
      next if group == nil

      spec_json['lifecycle'] = group['lifecycle'] || 'service'
      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(spec_json))
    end
  end
end
