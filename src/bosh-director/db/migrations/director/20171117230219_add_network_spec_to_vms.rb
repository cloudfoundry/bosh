Sequel.migration do
  up do
    alter_table(:vms) do
      add_column(:network_spec_json, String, default: '{}')
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
