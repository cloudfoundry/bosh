# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :log_bundles do
      primary_key :id
      String :blobstore_id, :null => false, :unique => true
      Time :timestamp, :null => false, :index => true
    end
  end
end
