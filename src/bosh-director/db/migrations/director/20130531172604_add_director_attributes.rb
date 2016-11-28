Sequel.migration do
  up do
    create_table(:director_attributes) do
      String :uuid, unique: true, null: false, primary_key: true
    end
  end

  down do
    drop_table(:director_attributes)
  end

end
