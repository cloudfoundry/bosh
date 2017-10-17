Sequel.migration do
  change do

    create_table :deployments_configs do
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      foreign_key :config_id, :configs, :null => false, :on_delete => :cascade
      unique [:deployment_id, :config_id], :name => :deployment_id_config_id_unique
    end

    default_uuid = SecureRandom.uuid

    self[:runtime_configs].each do |runtime_config|
      name = if runtime_config[:name].empty?
        'default'
      elsif runtime_config[:name] == 'default'
        "default-#{default_uuid}"
      else
        runtime_config[:name]
      end
      config_id = self[:configs].insert({
        type: 'runtime',
        name: name,
        content: runtime_config[:properties],
        created_at: runtime_config[:created_at]
      })
      self[:deployments_runtime_configs].where(runtime_config_id: [runtime_config[:id]]).each do |entry|
        self[:deployments_configs].insert(
          deployment_id: entry[:deployment_id],
          config_id: config_id
        )
      end
    end

    drop_table :deployments_runtime_configs
  end
end
