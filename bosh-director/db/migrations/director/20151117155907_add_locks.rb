Sequel.migration do
  up do
    create_table :locks do
      primary_key :id
      Time :expired_at, :null => false
      String :name, :unique => true, :null => false
      String :uid, :unique => true, :null => false
      index :name, :unique => true
    end
  end

  down do
    drop_table :locks
  end
end
