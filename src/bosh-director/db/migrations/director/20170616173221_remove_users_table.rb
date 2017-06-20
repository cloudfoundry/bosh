Sequel.migration do
  up do
    drop_table :users
  end
end
