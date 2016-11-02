Sequel.migration do
  change do
    self[:instances].all do |instance|
      next if instance[:spec_json] == nil
      spec_json = JSON.parse(instance[:spec_json])

      deployment = self[:deployments].where(id: instance[:deployment_id]).first
      deployment_manifest_yml = deployment[:manifest]
      next if deployment_manifest_yml == nil

      manifest_hash = YAML.load(deployment_manifest_yml)

      key = manifest_hash.has_key?('jobs') ? 'jobs' : 'instance_groups'
      group = manifest_hash[key].find do |instance_group|
        instance_group['name'] == instance[:job]
      end

      next if group == nil

      spec_json['lifecycle'] = group['lifecycle'] || 'service'
      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(spec_json))
    end
  end
end
