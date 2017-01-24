require 'securerandom'

Sequel.migration do
  up do
    drop_table :placeholder_mappings

    create_table :variable_mappings do
      primary_key :id
      String :variable_id, :null => false, :default => ''
      String :variable_name, :null => false, :default => ''
      String :set_id, :null => false, :default => ''
      index [:variable_name, :set_id], :unique => true, :name => :variables_set
    end

    alter_table(:deployments) do
      add_column(:variables_set_id, String, null: false, default: '')
      add_column(:successful_variables_set_id, String)
    end

    self[:deployments].each do |deployment|
      self[:deployments].filter(id: deployment[:id]).update(variables_set_id: deployment[:name])
    end

    alter_table(:instances) do
      add_column(:variables_set_id, String, null: false, default: '')
    end

    self[:instances].each do |instance|
      deployment_id = instance[:deployment_id]
      deployment = self[:deployments].filter(id: deployment_id).first
      self[:instances].filter(id: instance[:id]).update(variables_set_id: deployment[:name])
    end
  end

  down do
    drop_table :variable_mappings

    create_table :placeholder_mappings do
      primary_key :id
      String :placeholder_id, :null => false
      String :placeholder_name, :null => false
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      unique [:placeholder_id, :deployment_id] # reading the proper constraint
    end

    alter_table(:deployments) do
      drop_column(:variables_set_id)
      drop_column(:successful_variables_set_id)
    end

    alter_table(:instances) do
      drop_column(:variables_set_id)
    end
  end
end
