Sequel.migration do
  change do
    alter_table(:templates) do
      add_column :spec_json, String
    end

    if [:mysql,:mysql2].include? adapter_scheme
      set_column_type :templates, :spec_json, 'longtext'
    end

    self[:templates].all do |template|
      spec_hash = {}

      if JSON.load(template[:properties_json])
        spec_hash[:properties] = JSON.load(template[:properties_json])
      end

      if JSON.load(template[:consumes_json])
        spec_hash[:consumes] = JSON.load(template[:consumes_json])
      end

      if JSON.load(template[:provides_json])
        spec_hash[:provides] = JSON.load(template[:provides_json])
      end

      if JSON.load(template[:logs_json])
        spec_hash[:logs] = JSON.load(template[:logs_json])
      end

      if JSON.load(template[:templates_json])
        spec_hash[:templates] = JSON.load(template[:templates_json])
      end

      self[:templates].where(id: template[:id]).update(spec_json: JSON.dump(spec_hash))
    end
  end
end
