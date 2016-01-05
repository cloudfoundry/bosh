Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :credentials_json, String, :text => true
    end
    self[:instances].each do |row|
      if row.vm
        credentials_json = row.vm.credentials_json
        row.update(credentials_json: credentials_json)
      end
    end
  end
end
