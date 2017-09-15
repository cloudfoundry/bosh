Sequel.migration do
  change do
    create_table :deployments_runtime_configs do
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      foreign_key :runtime_config_id, :runtime_configs, :null => false, :on_delete => :cascade
      unique [:deployment_id, :runtime_config_id], :name => :deployment_id_runtime_config_id_unique
    end

    self[:deployments].each do |deployment|
      unless deployment[:runtime_config_id].nil?
        self[:deployments_runtime_configs].insert(deployment_id: deployment[:id], runtime_config_id: deployment[:runtime_config_id])
      end
    end

    alter_table(:deployments) do
      drop_foreign_key :runtime_config_id
    end
  end
end
