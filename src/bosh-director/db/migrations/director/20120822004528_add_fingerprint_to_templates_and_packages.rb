Sequel.migration do
  change do
    alter_table(:packages) do
      add_column :fingerprint, String
      add_index :fingerprint
      add_index :sha1
    end

    alter_table(:templates) do
      add_column :fingerprint, String
      add_index :fingerprint
      add_index :sha1
    end
  end
end