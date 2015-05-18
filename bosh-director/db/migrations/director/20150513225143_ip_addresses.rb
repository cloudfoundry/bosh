Sequel.migration do
  change do
    create_table :ip_addresses do
      primary_key :id
      String      :network_name
      Bignum      :address
      foreign_key :deployment_id, :deployments, :null => false

      unique [:address, :network_name]
    end
  end
end
