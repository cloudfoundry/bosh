Sequel.migration do
  up do
    create_table(:cloud_errors) do
      primary_key :id
      String :type
      String :data, :text => true, :null => true
    end
  end

  down do
    drop_table(:cloud_errors)
  end
end
