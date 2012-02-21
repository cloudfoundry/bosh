# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table(:tasks) do
      add_foreign_key :user_id, :users
    end
  end
end