Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :vm_cid, String, unique: true
      add_column :agent_id, String, unique: true
      add_column :credentials_json, String, :text => true
      add_column :vm_env_json, String, :text => true
      add_column :trusted_certs_sha1, String, { :default => Digest::SHA1.hexdigest('') }
    end
    self[:instances].each do |row|
      if row[:vm]
        vm_cid = row[:vm][:cid]
        agent_id = row[:vm][:agent_id]
        credentials_json = row[:vm][:credentials_json]
        trusted_certs_sha1 = row[:vm][:trusted_certs_sha1]
        vm_env_json = row[:vm][:env_json]

        row.update(
          vm_cid: vm_cid,
          agent_id: agent_id,
          vm_env_json: vm_env_json,
          trusted_certs_sha1: trusted_certs_sha1,
          credentials_json: credentials_json)
      end
    end
  end
end
