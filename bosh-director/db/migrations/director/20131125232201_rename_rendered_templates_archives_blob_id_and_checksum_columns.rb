Sequel.migration do
  change do
    drop_table(:rendered_templates_archives)

    create_table(:rendered_templates_archives) do
      primary_key :id
      foreign_key :instance_id, :instances, null: false

      String :blobstore_id, null: false
      String :sha1,         null: false
      String :content_sha1, null: false
      Time   :created_at, null: false

      index :created_at
    end
  end
end
