Sequel.migration do
  up do
    # mysql doesn't let us drop tasks' user_id column because it has a foreign key,
    # and sequel won't let us drop the foreign key, so we're recreating the table
    # from scratch. Sorry.

    create_table :tasks_new do
      primary_key :id
      String :state, :null => false
      Time :timestamp, :null => false
      String :description, :null => false
      String :result, :text => true, :null => true
      String :output, :null => true
      Time :checkpoint_time
      String :type, :null => false
      String :username, :null => true
    end

    run "INSERT INTO tasks_new
           (state, timestamp, description, result, output, checkpoint_time, type, username)
         SELECT t.state, t.timestamp, t.description, t.result, t.output, t.checkpoint_time, t.type, u.username
           FROM tasks t
             LEFT OUTER JOIN users u ON t.user_id = u.id"

    drop_table :tasks
    rename_table :tasks_new, :tasks

    alter_table :tasks do
      add_index :state
      add_index :timestamp
      add_index :description
    end
  end

  down do
    raise Sequel::Error, "Irreversible migration, tasks:user_id might contain nulls so we cannot enforce 'not null' constraint"
  end
end
