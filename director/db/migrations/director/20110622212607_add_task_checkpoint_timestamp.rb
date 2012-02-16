# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column(:checkpoint_time, Time)
    end
  end
end
