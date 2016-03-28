Sequel.migration do
  up do
    create_table(:director_attributes) do
      primary_key :uuid
      String :uuid, unique: true, null: false
    end
  end

  down do
    drop_table(:director_attributes)
  end

end
