Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :vm_env_json, String, :text => true
    end
    self[:instances].each do |row|
      if row.vm
        vm_env_json = row.vm.env_json
        row.update(vm_env_json: vm_env_json)
      end
    end
  end
end
