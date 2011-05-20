Sequel.migration do
  up do
    alter_table(:vms) do
      set_column_allow_null :cid, true
    end
  end

  down do
    alter_table(:vms) do
      set_column_allow_null :cid, false
    end
  end
end
