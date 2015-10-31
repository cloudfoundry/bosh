Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :spec_json, String, text: true
    end

    self[:instances].each do |instance|
      next unless instance[:vm_id]

      vm = self[:vms].filter(id: instance[:vm_id]).first

      self[:instances].filter(id: instance[:id]).update(spec_json: vm[:apply_spec_json])
    end

    alter_table(:vms) do
      drop_column(:apply_spec_json)
    end
  end
end
