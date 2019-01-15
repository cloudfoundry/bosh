Sequel.migration do
  up do
    alter_table :tasks do
      add_index :type
    end
  end
end
