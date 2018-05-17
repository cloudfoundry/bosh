require 'json'

Sequel.migration do
  up do
    json_column_type = String
    json_column_type = 'longtext' if %I[mysql2 mysql].include?(adapter_scheme)

    alter_table(:vms) do
      add_column(:stemcell_name, String)
      add_column(:stemcell_version, String)
      add_column(:env_json, json_column_type)
      add_column(:cloud_properties_json, json_column_type)
    end

    self[:vms].all do |vm|
      instance = self[:instances].where(id: vm[:instance_id]).first
      raw_spec_json = String(instance[:spec_json])
      spec_json = JSON.parse(raw_spec_json == '' ? '{}' : raw_spec_json)
      if spec_json['stemcells']
        stemcell_name = String(spec_json['stemcells']['name'])
        stemcell_version = String(spec_json['stemcells']['version'])
      end
      cloud_properties_hash = Hash(spec_json['vm_type']['cloud_properties']) if spec_json['vm_type']

      self[:vms].where(id: vm[:id]).update(
        stemcell_name: stemcell_name,
        stemcell_version: stemcell_version,
        env_json: Hash(spec_json['env']).to_json,
        cloud_properties_json: cloud_properties_hash.to_json,
      )
    end
  end
end
