Sequel.migration do
  change do
    create_table :rendered_templates_archives do
      primary_key :id
      foreign_key :instance_id, :instances, null: false

      String :blob_id, null: false
      String :checksum, null: false

      Time :created_at, null: false

      index :blob_id
      index :created_at
    end
  end
end
