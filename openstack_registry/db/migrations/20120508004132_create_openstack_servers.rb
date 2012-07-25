# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :openstack_servers do
      primary_key :id

      String :server_id, :null => false, :unique => true
      String :settings, :null => false, :text => true
    end
  end
end