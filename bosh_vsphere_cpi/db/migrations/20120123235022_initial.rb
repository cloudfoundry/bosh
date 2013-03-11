# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  # there is a bug in sequel where create_table? on postgres causes the transaction to abort with:
  # PG::Error: ERROR:  current transaction is aborted, commands ignored until end of transaction block
  # to work around this until it is fixed, transactions are disabled, which is fine as it is an atomic operation
  no_transaction

  up do
    # This used to be included in the director migrations, so we should not fail (hence create_table?) if this table
    # already exists to allow old installations to keep working with the new migrations.
    create_table? :vsphere_disk do
      primary_key :id
      String :path, :null => true
      String :datacenter, :null => true
      String :datastore, :null => true
      Integer :size, :null => false
    end
  end

  down do
    drop_table :vsphere_disk
  end
end
