Sequel.migration do
  change do
    add_column :instances, :tainted, :boolean, default: false
  end
end
