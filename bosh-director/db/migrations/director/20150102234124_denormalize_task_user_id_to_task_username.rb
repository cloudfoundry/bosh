Sequel.migration do
  up do
    alter_table(:tasks) do
      add_column(:username, String)
    end

    self[:users].all.each do |user|
      self[:tasks].where(:user_id => user[:id]).update(:username => user[:username])
    end

    alter_table(:tasks) do
      drop_column(:user_id)
    end
  end

  down do
    raise Sequel::Error, "Irreversible migration, tasks:user_id might contain nulls so we cannot enforce 'not null' constraint"
  end
end
