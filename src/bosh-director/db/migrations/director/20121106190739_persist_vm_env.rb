# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table(:vms) do
      add_column :env_json, String, :text => true
    end
  end
end
