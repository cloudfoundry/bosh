Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :vm_cid, String, unique: true
      add_column :agent_id, String, unique: true
      add_column :credentials_json, String, :text => true
      add_column :vm_env_json, String, :text => true
      add_column :trusted_certs_sha1, String, { :default => Digest::SHA1.hexdigest('') }
    end

    self[:instances].each do |instance|
      next unless instance[:vm_id]

      vm = self[:vms].filter(id: instance[:vm_id]).first

      self[:instances].filter(id: instance[:id]).update(
        vm_cid: vm[:cid],
        agent_id: vm[:agent_id],
        vm_env_json: vm[:env_json],
        trusted_certs_sha1: vm[:trusted_certs_sha1],
        credentials_json: vm[:credentials_json]
      )
    end
  end
end
