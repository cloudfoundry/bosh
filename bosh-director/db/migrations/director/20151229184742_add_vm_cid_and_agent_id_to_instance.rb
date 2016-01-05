Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :vm_cid, String, unique: true
      add_column :agent_id, String, unique: true
    end
    self[:instances].each do |row|
      if row.vm
        vm_cid = row.vm.cid
        agent_id = row.vm.agent_id
        row.update(vm_cid: vm_cid, agent_id: agent_id)
      end
    end
  end
end
