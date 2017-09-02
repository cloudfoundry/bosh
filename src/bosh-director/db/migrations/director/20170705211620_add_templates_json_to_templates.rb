Sequel.migration do
  up do
    adapter_scheme =  self.adapter_scheme
    alter_table(:templates) do
      add_column :templates_json, [:mysql2, :mysql].include?(adapter_scheme) ? 'longtext' : 'text'
    end
  end
end

