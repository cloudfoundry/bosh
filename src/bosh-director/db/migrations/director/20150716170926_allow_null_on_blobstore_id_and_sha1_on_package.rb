Sequel.migration do
  change do
    alter_table(:packages) do
      set_column_allow_null :blobstore_id, true
      set_column_allow_null :sha1, true
    end
  end
end