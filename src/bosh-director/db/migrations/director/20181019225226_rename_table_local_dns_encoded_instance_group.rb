Sequel.migration do
  up do
    rename_table :local_dns_encoded_instance_groups, :local_dns_encoded_groups
  end
end
