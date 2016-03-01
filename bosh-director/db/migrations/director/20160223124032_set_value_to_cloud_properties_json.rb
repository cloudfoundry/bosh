Sequel.migration do
  up do
    alter_table(:persistent_disks) do
      set_column_default :cloud_properties_json, '{}'
    end

    from(:persistent_disks).where(:cloud_properties_json=>'').update(:cloud_properties_json=>'{}')
  end

  down do
    raise Sequel::Error, "Irreversible migration, the default value of cloud_properties_json should always be '{}'."
  end
end