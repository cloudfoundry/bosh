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

    create_table :link_consumers do
      primary_key :id
      foreign_key :deployment_id, :deployments, :on_delete => :cascade
      String :instance_group
      String :owner_object_name, :null => false
      String :owner_object_type, :null => false
    end

    create_table :links do
      primary_key :id
      foreign_key :link_provider_id, :link_providers, :on_delete => :set_null
      foreign_key :link_consumer_id, :link_consumers, :on_delete => :cascade, :null => false
      String :name, :null => false
      String :link_content
      Time :created_at
    end

    create_table :instances_links do
      foreign_key :link_id, :links, :on_delete => :cascade, :null => false
      foreign_key :instance_id, :instances, :on_delete => :cascade, :null => false
      unique [:instance_id, :link_id]
    end

    if [:mysql, :mysql2].include? adapter_scheme
      set_column_type :link_providers, :content, 'longtext'
      set_column_type :links, :link_content, 'longtext'
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

    links_to_migrate = {}

    Struct.new('LinkKey', :deployment_id, :instance_group, :job, :link_name) unless defined?(Struct::LinkKey)
    Struct.new('LinkDetail', :link_id, :content) unless defined?(Struct::LinkDetail)

    self[:instances].each do |instance|
      spec_json = JSON.parse(instance[:spec_json] || '{}')
      links = spec_json['links'] || {}
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

          link_key = Struct::LinkKey.new(instance[:deployment_id], instance[:job], job_name, link_name)

          link_details = links_to_migrate[link_key] || []
          link_detail = link_details.find do |link_detail|
            link_detail.content == link_data
          end

          unless link_detail
            consumer = self[:link_consumers].where(deployment_id: instance[:deployment_id], instance_group: instance[:job], owner_object_name: job_name).first
            raise "Could not find an appropriate consumer for this instance." unless consumer

            link_id = self[:links].insert(
              {
                name: link_name,
                link_provider_id: nil,
                link_consumer_id: consumer[:id],
                link_content: link_data.to_json,
                created_at: Time.now,
              }
            )
            link_detail = Struct::LinkDetail.new(link_id, link_data)

            link_details << link_detail
            links_to_migrate[link_key] = link_details
          end

          self[:instances_links] << {
            link_id: link_detail.link_id,
            instance_id: instance[:id]
          }
        end
      end
    end
  end
end
