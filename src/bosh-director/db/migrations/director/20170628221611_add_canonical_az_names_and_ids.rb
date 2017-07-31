Sequel.migration do
  up do
    create_table :local_dns_encoded_azs do
      primary_key :id
      String :name, text: true, unique: true, null: false
    end
  end
end
