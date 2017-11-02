Sequel.migration do
  up do
    create_table :link_providers do
      primary_key :id
      String :name, :null => false
      Boolean :shared, :null => false
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      String :instance_group, :null => false
      Boolean :consumable, :null => false
      String :content, :null => false
      String :link_provider_definition_type, :null => false
      String :link_provider_definition_name, :null => false # Original name. Only for debugging.
      String :owner_object_name, :null => false
      String :owner_object_type, :null => false
    end

    if [:mysql, :mysql2].include? adapter_scheme
      set_column_type :link_providers, :content, 'longtext'
      set_column_type :links, :content, 'longtext'
    end

    self[:deployments].each do |deployment|
      link_spec_json = JSON.parse(deployment[:link_spec_json] || '{}')
      link_spec_json.each do |instance_group_name, provider_jobs|
        provider_jobs.each do |provider_job_name, link_names|
          link_names.each do |link_name, link_types|
            link_types.each do |link_type, content|
              self[:link_providers] << {
                name: link_name,
                deployment_id: deployment[:id],
                instance_group: instance_group_name,
                shared: true,
                consumable: true,
                link_provider_definition_type: link_type,
                link_provider_definition_name: link_name,
                owner_object_name: provider_job_name,
                owner_object_type: 'job',
                content: content.to_json,
              }
            end
          end
        end
      end
    end

    create_table :link_consumers do
      primary_key :id
      foreign_key :deployment_id, :deployments, :on_delete => :cascade
      String :instance_group
      String :owner_object_name, :null => false
      String :owner_object_type, :null => false
    end

    self[:instances].each do |instance|
      spec_json = JSON.parse(instance[:spec_json] || '{}')
      links = spec_json['links']
      links.each do |job_name, consumed_links|
        consumed_links.each do |link_name, link_data|
          if self[:link_consumers].where(deployment_id: instance[:deployment_id], instance_group: instance[:job], owner_object_name: job_name).all.count == 0
            self[:link_consumers] << {
              deployment_id: instance[:deployment_id],
              instance_group: instance[:job],
              owner_object_name: job_name,
              owner_object_type: 'Job'
            }
          end
        end
      end
    end

    #TODO: Migrate instance.spec_json's link spec to links table.
  end
end
