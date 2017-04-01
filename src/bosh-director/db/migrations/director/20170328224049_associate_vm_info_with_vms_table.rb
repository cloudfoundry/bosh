Sequel.migration do
  up do
    alter_table(:instances) do
      drop_foreign_key :vm_id
    end

    drop_table :vms

    create_table :vms do
      primary_key :id
      foreign_key :instance_id, :instances, null: true
      String :agent_id, unique: true
      String :cid, unique: true
      String :credentials_json
      String :trusted_certs_sha1, {:default => ::Digest::SHA1.hexdigest('')}
    end

    if [:mysql2, :mysql].include?(adapter_scheme)
      alter_table(:vms) do
        set_column_type :credentials_json, 'longtext'
      end
    end

    alter_table(:instances) do
      add_column :active_vm_id, Integer
      add_foreign_key [:active_vm_id], :vms, name: :instance_vm_id_fkey, unique: true
    end

    self[:instances].each do |instance|
      if instance[:vm_cid]
        vm_id = self[:vms].insert(
          instance_id: instance[:id],
          cid: instance[:vm_cid],
          agent_id: instance[:agent_id],
          credentials_json: instance[:credentials_json],
          trusted_certs_sha1: instance[:trusted_certs_sha1],
        )

        self[:instances].where(id: instance[:id]).update(
          active_vm_id: vm_id
        )
      end
    end

    alter_table(:instances) do
      rename_column :vm_cid, :vm_cid_bak
      rename_column :credentials_json, :credentials_json_bak
      rename_column :agent_id, :agent_id_bak
      rename_column :trusted_certs_sha1, :trusted_certs_sha1_bak
    end
  end
end
