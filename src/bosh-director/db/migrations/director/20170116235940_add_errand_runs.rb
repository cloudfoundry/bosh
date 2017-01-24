Sequel.migration do
  change do
    create_table :errand_runs do
      primary_key :id

      TrueClass :successful, :default => false
      String :successful_configuration_hash, :text => true
      String :successful_packages_spec, :text => true

      foreign_key :instance_id, :instances, :null => false, :on_delete => :cascade, :foreign_key_constraint_name => 'errands_instance_id_fkey'
    end
  end
end
