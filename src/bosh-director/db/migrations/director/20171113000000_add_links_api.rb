Sequel.migration do
  up do
    create_table :link_providers do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      String :instance_group, :null => false
      String :name, :null => false
      String :type, :null => false
      Integer :serial_id
    end

    alter_table(:link_providers) do
      add_index [:deployment_id, :instance_group, :name, :type], unique: true, name: 'link_providers_constraint'
    end

    create_table :link_provider_intents do
      primary_key :id
      foreign_key :link_provider_id, :link_providers, :on_delete => :cascade
      String :original_name, :null => false
      String :type, :null => false
      String :name # This should never be null, but... because when we find/create we don't use it as a constraint and it can be updated at any moment.. We can't enforce it to start off as non-null.
      String :content # rely on networks, make optional because of delayed content resolution
      Boolean :shared, :null => false, :default => false
      Boolean :consumable, :null => false, :default => true
      String :metadata #mapped properties
      Integer :serial_id
    end

    alter_table(:link_provider_intents) do
      add_index [:link_provider_id, :original_name], unique: true, name: 'link_provider_intents_constraint'
    end

    create_table :link_consumers do
      primary_key :id
      foreign_key :deployment_id, :deployments, :on_delete => :cascade
      String :instance_group
      String :name, :null => false
      String :type, :null => false
      Integer :serial_id
    end

    alter_table(:link_consumers) do
      add_index [:deployment_id, :instance_group, :name, :type], unique: true, name: 'link_consumers_constraint'
    end

    create_table :link_consumer_intents do
      primary_key :id
      foreign_key :link_consumer_id, :link_consumers, :on_delete => :cascade
      String :original_name, :null => false
      String :type, :null => false
      String :name # This should never be null, but... because when we find/create we don't use it as a constraint and it can be updated at any moment.. We can't enforce it to start off as non-null.
      Boolean :optional, :null => false, :default => false
      Boolean :blocked, :null => false, :default => false # intentionally blocking the consumption of the link, consume: nil
      String :metadata # put extra json object that has some flags, ip addresses true or false, network, from_deployment or any other potential thing
      Integer :serial_id
    end

    alter_table(:link_consumer_intents) do
      add_index [:link_consumer_id, :original_name], unique: true, name: 'link_consumer_intents_constraint'
    end

    create_table :links do
      primary_key :id
      foreign_key :link_provider_intent_id, :link_provider_intents, :on_delete => :set_null
      foreign_key :link_consumer_intent_id, :link_consumer_intents, :on_delete => :cascade, :null => false
      String :name, :null => false
      String :link_content
      Time :created_at
    end

    create_table :instances_links do
      primary_key :id
      foreign_key :link_id, :links, :on_delete => :cascade, :null => false
      foreign_key :instance_id, :instances, :on_delete => :cascade, :null => false
      Integer :serial_id
    end

    alter_table(:instances_links) do
      add_index [:link_id, :instance_id], unique: true, name: 'instances_links_constraint'
    end

    alter_table(:deployments) do
      add_column :has_stale_errand_links, 'boolean', null: false, default: false
    end

    if [:mysql, :mysql2].include? adapter_scheme
      set_column_type :link_provider_intents, :content, 'longtext'
      set_column_type :links, :link_content, 'longtext'
    end

    self[:deployments].each do |deployment|
      link_spec_json = JSON.parse(deployment[:link_spec_json] || '{}')
      link_spec_json.each do |instance_group_name, provider_jobs|
        provider_jobs.each do |provider_job_name, link_names|
          provider_id = self[:link_providers].insert({
            deployment_id: deployment[:id],
            name: provider_job_name,
            type: 'job',
            instance_group: instance_group_name,
            serial_id: 0,
          })

          link_names.each do |link_name, link_types|
            link_types.each do |link_type, content|
              self[:link_provider_intents].insert(
                {
                  link_provider_id: provider_id,
                  original_name: link_name,
                  type: link_type,
                  name: link_name,
                  shared: true,
                  consumable: true,
                  content: content.to_json,
                  serial_id: 0,
                }
              )
            end
          end
        end
      end
    end

    self[:deployments].update(has_stale_errand_links: true)

    links_to_migrate = {}

    Struct.new('LinkKey', :deployment_id, :instance_group, :job, :link_name) unless defined?(Struct::LinkKey)
    Struct.new('LinkDetail', :link_id, :content) unless defined?(Struct::LinkDetail)

    self[:instances].each do |instance|
      spec_json = JSON.parse(instance[:spec_json] || '{}')
      links = spec_json.delete('links') || {}
      links.each do |job_name, consumed_links|
        consumer = self[:link_consumers].where(deployment_id: instance[:deployment_id], instance_group: instance[:job], name: job_name).first

        if consumer
          consumer_id = consumer[:id]
        else
          consumer_id = self[:link_consumers].insert(
            {
              deployment_id: instance[:deployment_id],
              instance_group: instance[:job],
              name: job_name,
              type: 'job',
              serial_id: 0,
            }
          )
        end

        consumed_links.each do |link_name, link_data|
          link_key = Struct::LinkKey.new(instance[:deployment_id], instance[:job], job_name, link_name)

          # since we can go through multiple instances
          link_details = links_to_migrate[link_key] || []
          link_detail = link_details.find do |link_detail|
            link_detail.content == link_data
          end

          link_consumer_intent = self[:link_consumer_intents].where(link_consumer_id: consumer_id, original_name: link_name).first

          if link_consumer_intent
            link_consumer_intent_id = link_consumer_intent[:id]
          else
            # #153608828 set original name and alias to the same value (link_name from consumed_links)
            link_consumer_intent_id = self[:link_consumer_intents].insert(
              {
                link_consumer_id: consumer_id,
                original_name: link_name,
                name: link_name,
                type: 'undefined-migration',
                optional: false,
                blocked: false,
                serial_id: 0
              }
            )
          end

          unless link_detail
            link_id = self[:links].insert(
              {
                name: link_name,
                link_provider_intent_id: nil,
                link_consumer_intent_id: link_consumer_intent_id,
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
            instance_id: instance[:id],
            serial_id: 0,
          }
        end
      end
      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(spec_json))
    end

    alter_table(:deployments) do
      drop_column :link_spec_json
      add_column :links_serial_id, Integer, default: 0
    end
  end
end
