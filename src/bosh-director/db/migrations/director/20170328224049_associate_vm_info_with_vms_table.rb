Sequel.migration do
  up do
    drop_table :vms

    alter_table(:instances) do
      drop_column(:vm_id)
    end

    create_table :vms do
      primary_key :id
      foreign_key :instance_id, :instances, null: true
      text :agent_id, unique: true
      text :cid, unique: true
      longtext :credentials_json
      text :trusted_certs_sha1, { :default => ::Digest::SHA1.hexdigest('') }
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
