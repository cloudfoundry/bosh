# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :agent_settings do
      primary_key :id

      String :ip_address, :null => false, :unique => true
      String :settings, :null => false, :text => true
    end
  end
end
