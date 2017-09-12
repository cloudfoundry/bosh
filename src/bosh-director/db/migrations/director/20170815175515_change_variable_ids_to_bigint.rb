Sequel.migration do
  change do
    # sqlite uses bigint for all int fields already, so skip this
    # (and if we try to do this on sqlite, it breaks the primary key sequence)
    next if adapter_scheme == :sqlite

    alter_table(:instances) do
      drop_foreign_key [:variable_set_id], name: :instance_table_variable_set_fkey
    end
    alter_table(:variables) do
      drop_foreign_key [:variable_set_id]
    end

    set_column_type :variable_sets, :id, :Bignum
    set_column_type :instances, :variable_set_id, :Bignum
    set_column_type :variables, :variable_set_id, :Bignum

    alter_table(:instances) do
      add_foreign_key [:variable_set_id], :variable_sets, :name=>:instance_table_variable_set_fkey
    end
    alter_table(:variables) do
      add_foreign_key [:variable_set_id], :variable_sets, :name=>:variable_table_variable_set_fkey, :on_delete => :cascade
    end

    set_column_type :variables, :id, :Bignum

  end
end
