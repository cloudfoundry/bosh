Sequel.migration do
  change do
    create_table :agent_dns_versions do
      primary_key :id
      String :agent_id, :unique => true, :null => false
      Integer :dns_version, :default => 0, :null => false
    end
  end
end
