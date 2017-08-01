Sequel.migration do
  up do
    create_table :local_dns_encoded_azs do
      primary_key :id
      String :name, unique: true, null: false
    end

    if [:mysql2, :mysql].include?(adapter_scheme)
      set_column_type :compiled_packages, :dependency_key, 'longtext'
    end
  end
end
