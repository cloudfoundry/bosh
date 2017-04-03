Sequel.migration do
  up do
    alter_table(:instances) do
      drop_foreign_key :active_vm_id
    end

    alter_table(:vms) do
      add_column :active, TrueClass, default: false
    end

    self[:vms].update(active: true)
  end
end
