Sequel.migration do
  change do
    create_table :ip_addresses do
      primary_key :id
      String      :network_name
      Bignum      :address
      foreign_key :instance_id, :instances

      unique [:address, :network_name]
    end
  end
end
