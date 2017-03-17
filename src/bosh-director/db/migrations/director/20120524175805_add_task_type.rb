Sequel.migration do
  up do
    alter_table :tasks do
      add_column :type, String
      add_index :description
    end

    self[:tasks].filter(description: 'create deployment').
        update(:type => 'update_deployment')
    self[:tasks].grep(:description, 'delete deployment:%').
        update(:type => 'delete_deployment')
    self[:tasks].filter(:description => 'fetch logs').
        update(:type => 'fetch_logs')
    self[:tasks].grep(:description, 'ssh:%').
        update(:type => 'ssh')
    self[:tasks].filter(:description => 'scan cloud').
        update(:type => 'cck_scan')
    self[:tasks].filter(:description => 'apply resolutions').
        update(:type => 'cck_apply')
    self[:tasks].filter(:description => 'retrieve vm-stats').
        update(:type => 'vms')
    self[:tasks].filter(:description => 'create release').
        update(:type => 'update_release')
    self[:tasks].grep(:description, 'delete release:%').
        update(:type => 'delete_release')
    self[:tasks].filter(:description => 'create stemcell').
        update(:type => 'update_stemcell')
    self[:tasks].grep(:description, 'delete stemcell:%').
        update(:type => 'delete_stemcell')

    alter_table :tasks do
      set_column_allow_null :type, false
    end
  end

  down do
    alter_table :tasks do
      remove_column :type
      drop_index :description
    end
  end
end
