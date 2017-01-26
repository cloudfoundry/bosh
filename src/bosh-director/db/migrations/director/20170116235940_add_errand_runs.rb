Sequel.migration do
  change do
    db_type = adapter_scheme
    create_table :errand_runs do
      primary_key :id

      TrueClass :successful, :default => false
      String :successful_configuration_hash, size: 512

      if [:mysql2, :mysql].include?(db_type)
        longtext :successful_packages_spec
      else
        String :successful_packages_spec, :text => true
      end

      foreign_key :instance_id, :instances, :null => false, :on_delete => :cascade, :foreign_key_constraint_name => 'errands_instance_id_fkey'
    end
  end
end
