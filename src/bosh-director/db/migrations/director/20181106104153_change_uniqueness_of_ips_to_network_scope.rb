Sequel.migration do
  up do
    alter_table(:ip_addresses) do
      drop_index %i[address_str]
      add_index %i[address_str network_name], unique: true
    end
  end
end