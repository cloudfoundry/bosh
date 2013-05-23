# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  up do
    create_table :deployments_releases do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false
      foreign_key :release_id, :releases, :null => false
      unique [:deployment_id, :release_id]
    end

    self[:deployments].each do |deployment|
      attrs = {
        :release_id => deployment[:release_id],
        :deployment_id => deployment[:id]
      }

      self[:deployments_releases].insert(attrs)
    end

    alter_table :deployments do
      drop_foreign_key :release_id
    end
  end

  down do
    raise Sequel::Error, "Irreversible migration, cannot easily go from " +
                          "many-to-many to one-to-many"
  end
end
