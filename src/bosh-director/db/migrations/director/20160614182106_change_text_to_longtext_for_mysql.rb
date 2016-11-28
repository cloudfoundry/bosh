Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)
      set_column_type :compiled_packages, :dependency_key, 'longtext'
      set_column_type :deployment_problems, :data_json, 'longtext'
      set_column_type :deployment_properties, :value, 'longtext'
      set_column_type :deployments, :link_spec_json, 'longtext'
      set_column_type :director_attributes, :value, 'longtext'
      set_column_type :instances, :cloud_properties, 'longtext'
      set_column_type :instances, :dns_records, 'longtext'
      set_column_type :instances, :spec_json, 'longtext'
      set_column_type :instances, :credentials_json, 'longtext'
      set_column_type :orphan_disks, :cloud_properties_json, 'longtext'
      set_column_type :packages, :dependency_set_json, 'longtext'
      set_column_type :persistent_disks, :cloud_properties_json, 'longtext'
      set_column_type :templates, :package_names_json, 'longtext'
      set_column_type :templates, :logs_json, 'longtext'
      set_column_type :templates, :properties_json, 'longtext'
    end
  end
end
