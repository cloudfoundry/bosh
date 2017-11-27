Sequel.migration do
  up do
    column_type = String
    if [:mysql2, :mysql].include?(adapter_scheme)
      column_type = 'longtext'
    end

    alter_table(:vms) do
      add_column(:network_spec_json, column_type)
    end

    self[:vms].all do |vm|
      if vm[:active] == true
        instance = self[:instances].where(id: vm[:instance_id]).first
        instance_spec = JSON.parse(instance[:spec_json])
        self[:vms].where(id: vm[:id]).update(network_spec_json: JSON.dump(instance_spec['networks']))
      end
    end
  end
end
