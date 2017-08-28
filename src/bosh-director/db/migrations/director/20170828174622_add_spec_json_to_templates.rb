Sequel.migration do
  change do
    alter_table(:templates) do
      add_column :spec_json, String
    end

    if [:mysql,:mysql2].include? adapter_scheme
      set_column_type :templates, :spec_json, 'longtext'
    end
  end
end
