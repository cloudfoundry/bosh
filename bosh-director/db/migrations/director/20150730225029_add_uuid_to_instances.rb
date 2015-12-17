require('securerandom')

Sequel.migration do
  up do
    alter_table(:instances) do
      add_column :uuid, String, unique: true
    end
    self[:instances].each { |row| self[:instances].filter(id: row[:id]).update(uuid: SecureRandom.uuid) }
  end

  down do
    alter_table(:instances) do
      drop_column :uuid
    end
  end
end
