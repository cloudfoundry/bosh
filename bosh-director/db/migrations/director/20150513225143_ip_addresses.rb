Sequel.migration do
  change do
    create_table :ip_addresses do
      primary_key :id
      String      :network_name
      Integer     :address

      unique [:address, :network_name]
    end
  end
end
