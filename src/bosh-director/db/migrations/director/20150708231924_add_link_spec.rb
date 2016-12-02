Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :link_spec_json, String, :text => true
    end
  end
end
