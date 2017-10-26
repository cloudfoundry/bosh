Sequel.migration do
  change do
    self[:cloud_configs].each do |cloud_config|
      config_id = self[:configs].insert({
        type: 'cloud',
        name: 'default',
        content: cloud_config[:properties],
        created_at: cloud_config[:created_at]
      })
      self[:deployments].where(cloud_config_id: cloud_config[:id]).each do |entry|
        self[:deployments_configs].insert(
          deployment_id: entry[:id],
          config_id: config_id
        )
      end
    end

    alter_table(:deployments) do
      drop_foreign_key :cloud_config_id
    end

  end
end
