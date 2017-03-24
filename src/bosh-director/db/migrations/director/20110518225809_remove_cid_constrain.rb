Sequel.migration do
  up do
    alter_table(:vms) do
      set_column_allow_null :cid, true
    end
  end

  down do
    raise Sequel::Error, "Irreversible migration, vms:cid might contain nulls so we cannot enforce 'not null' constraint"
  end
end
