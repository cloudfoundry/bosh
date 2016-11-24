Sequel.migration do
  change do
    create_table :ip_addresses do
      primary_key :id
      String      :network_name
      Bignum      :address, unique: true
      TrueClass     :static
      foreign_key :instance_id, :instances
    end
  end
end
