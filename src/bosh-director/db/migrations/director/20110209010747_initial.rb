Sequel.migration do
  change do
    create_table :releases do
      primary_key :id
      String :name, :null => false, :unique => true
    end

    create_table :release_versions do
      primary_key :id
      String :version, :null => false
      foreign_key :release_id, :releases, :null => false
    end

    create_table :packages do
      primary_key :id
      String :name, :null => false
      String :version, :null => false
      String :blobstore_id, :null => false
      String :sha1, :null => false
      String :dependency_set_json, :null => false, :text => true
      foreign_key :release_id, :releases, :null => false
      unique [:release_id, :name, :version]
    end

    create_table :templates do
      primary_key :id
      String :name, :null => false
      String :version, :null => false
      String :blobstore_id, :null => false
      String :sha1, :null => false
      String :package_names_json, :null => false, :text => true
      foreign_key :release_id, :releases, :null => false
      unique [:release_id, :name, :version]
    end

    create_table :stemcells do
      primary_key :id
      String :name, :null => false
      String :version, :null => false
      String :cid, :null => false
      unique [:name, :version]
    end

    create_table :compiled_packages do
      primary_key :id
      String :blobstore_id, :null => false
      String :sha1, :null => false
      String :dependency_key, :null => false
      Integer :build, :unsigned => true, :null => false
      foreign_key :package_id, :packages, :null => false
      foreign_key :stemcell_id, :stemcells, :null => false
      unique [:package_id, :stemcell_id, :dependency_key]
      unique [:package_id, :stemcell_id, :build]
    end

    create_table :deployments do
      primary_key :id
      String :name, :null => false, :unique => true
      String :manifest, :null => true, :text => true
      foreign_key :release_id, :releases, :null => true
    end

    create_table :vms do
      primary_key :id
      String :agent_id, :null => false, :unique => true
      String :cid, :null => false
      foreign_key :deployment_id, :deployments, :null => false
    end

    create_table :instances do
      primary_key :id
      String :job, :null => false
      Integer :index, :unsigned => true, :null => false
      String :disk_cid, :unique => true, :null => true
      foreign_key :deployment_id, :deployments, :null => false
      foreign_key :vm_id, :vms, :unique => true, :null => true
    end

    create_table :tasks do
      primary_key :id
      String :state, :index => true, :null => false
      Time :timestamp, :index => true, :null => false
      String :description, :null => false
      String :result, :text => true, :null => true
      String :output, :null => true
    end

    create_table :users do
      primary_key :id
      String :username, :unique => true, :null => false
      String :password, :null => false
    end

    create_table :packages_release_versions do
      primary_key :id
      foreign_key :package_id, :packages, :null => false
      foreign_key :release_version_id, :release_versions, :null => false
      unique [:package_id, :release_version_id]
    end

    create_table :release_versions_templates do
      primary_key :id
      foreign_key :release_version_id, :release_versions, :null => false
      foreign_key :template_id, :templates, :null => false
      unique [:release_version_id, :template_id]
    end

    create_table :deployments_stemcells do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false
      foreign_key :stemcell_id, :stemcells, :null => false
      unique [:deployment_id, :stemcell_id]
    end

  end
end
