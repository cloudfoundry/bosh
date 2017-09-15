Sequel.migration do
  up do
    alter_table(:instances) do
      add_column(:state, String)
    end

    self[:instances].update(:state => "started")

    alter_table(:instances) do
      set_column_allow_null :state, false
    end
  end

  down do
    alter_table(:instances) do
      drop_column(:state)
    end
  end
end
