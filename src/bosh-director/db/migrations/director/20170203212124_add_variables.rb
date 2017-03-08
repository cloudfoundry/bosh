Sequel.migration do
  up do
    create_table :variable_sets do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade
      Time :created_at, null: false, :index => true
    end

    create_table :variables do
      primary_key :id
      String :variable_id, :null => false
      String :variable_name, :null => false
      foreign_key :variable_set_id, :variable_sets, :null => false, :on_delete => :cascade
      index [:variable_set_id, :variable_name], :unique => true, :name => :variable_set_id_variable_name
    end

    self[:deployments].each do |deployment|
      self[:variable_sets].insert(deployment_id: deployment[:id], created_at: Time.now)
    end

    alter_table(:instances) do
      add_column :variable_set_id, Integer
    end

    self[:instances].each do |instance|
      variable_set = self[:variable_sets].filter(deployment_id: instance[:deployment_id]).first
      self[:instances].where(id: instance[:id]).update(variable_set_id: variable_set[:id])
    end

    alter_table(:instances) do
      set_column_not_null :variable_set_id
      add_foreign_key [:variable_set_id], :variable_sets, :name=>:instance_table_variable_set_fkey
    end
  end

  down do
    alter_table(:instances) do
      drop_foreign_key :variable_set_id
    end

    drop_table :variable_sets
    drop_table :variables
  end
end
