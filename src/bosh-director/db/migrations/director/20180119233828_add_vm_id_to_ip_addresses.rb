Sequel.migration do
  up do
    alter_table(:ip_addresses) do
      add_column :vm_id, Integer
    end

    self[:vms].all do |vm|
      if vm[:active] == true
        instance = self[:instances].where(id: vm[:instance_id]).first
        self[:ip_addresses].where(instance_id: instance[:id]).update(vm_id: vm[:id])
      end
    end
  end
end
