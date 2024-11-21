Sequel.migration do
  change do
    case adapter_scheme
    when :postgres
      begin
        create_table(:agent_dns_versions) do
          primary_key :id, :type=>:Bignum
          column :agent_id, "text", :null=>false
          column :dns_version, "bigint", :default=>0, :null=>false

          index [:agent_id], :unique=>true
        end

        create_table(:blobs) do
          primary_key :id
          column :blobstore_id, "text", :null=>false
          column :sha1, "text", :null=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :type, "text"
        end

        create_table(:cloud_configs) do
          primary_key :id
          column :properties, "text"
          column :created_at, "timestamp without time zone", :null=>false

          index [:created_at]
        end

        create_table(:configs) do
          primary_key :id
          column :name, "text", :null=>false
          column :type, "text", :null=>false
          column :content, "text", :null=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :deleted, "boolean", :default=>false
          column :team_id, "integer"
        end

        create_table(:cpi_configs) do
          primary_key :id
          column :properties, "text"
          column :created_at, "timestamp without time zone", :null=>false

          index [:created_at]
        end

        create_table(:delayed_jobs) do
          primary_key :id
          column :priority, "integer", :default=>0, :null=>false
          column :attempts, "integer", :default=>0, :null=>false
          column :handler, "text", :null=>false
          column :last_error, "text"
          column :run_at, "timestamp without time zone"
          column :locked_at, "timestamp without time zone"
          column :failed_at, "timestamp without time zone"
          column :locked_by, "text"
          column :queue, "text"

          index [:priority, :run_at]
        end

        create_table(:deployments) do
          primary_key :id
          column :name, "text", :null=>false
          column :manifest, "text"
          column :manifest_text, "text"
          column :has_stale_errand_links, "boolean", :default=>false, :null=>false
          column :links_serial_id, "integer", :default=>0

          index [:name], :unique=>true
        end

        create_table(:director_attributes) do
          column :value, "text"
          column :name, "text", :null=>false
          primary_key :id, :keep_order=>true

          index [:name], :unique=>true
        end

        create_table(:events) do
          primary_key :id, :type=>:Bignum
          column :parent_id, "bigint"
          column :user, "text", :null=>false
          column :timestamp, "timestamp without time zone", :null=>false
          column :action, "text", :null=>false
          column :object_type, "text", :null=>false
          column :object_name, "text"
          column :error, "text"
          column :task, "text"
          column :deployment, "text"
          column :instance, "text"
          column :context_json, "text"

          index [:timestamp]
        end

        create_table(:local_dns_encoded_azs) do
          primary_key :id
          column :name, "text", :null=>false

          index [:name], :unique=>true
        end

        create_table(:local_dns_encoded_networks) do
          primary_key :id
          column :name, "text", :null=>false

          index [:name], :unique=>true
        end

        create_table(:locks) do
          primary_key :id
          column :expired_at, "timestamp without time zone", :null=>false
          column :name, "text", :null=>false
          column :uid, "text", :null=>false
          column :task_id, "text", :default=>"", :null=>false

          index [:name], :unique=>true
          index [:uid], :unique=>true
        end

        create_table(:log_bundles) do
          primary_key :id
          column :blobstore_id, "text", :null=>false
          column :timestamp, "timestamp without time zone", :null=>false

          index [:blobstore_id], :unique=>true
          index [:timestamp]
        end

        create_table(:networks) do
          primary_key :id
          column :name, "text", :null=>false
          column :type, "text", :null=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :orphaned, "boolean", :default=>false
          column :orphaned_at, "timestamp without time zone"

          index [:name], :unique=>true
        end

        create_table(:orphan_disks) do
          primary_key :id
          column :disk_cid, "text", :null=>false
          column :size, "integer"
          column :availability_zone, "text"
          column :deployment_name, "text", :null=>false
          column :instance_name, "text", :null=>false
          column :cloud_properties_json, "text"
          column :created_at, "timestamp without time zone", :null=>false
          column :cpi, "text", :default=>""

          index [:disk_cid], :unique=>true
          index [:created_at]
        end

        create_table(:orphaned_vms) do
          primary_key :id
          column :cid, "text", :null=>false
          column :availability_zone, "text"
          column :cloud_properties, "text"
          column :cpi, "text"
          column :orphaned_at, "timestamp without time zone", :null=>false
          column :stemcell_api_version, "integer"
          column :deployment_name, "text"
          column :instance_name, "text"
        end

        create_table(:releases) do
          primary_key :id
          column :name, "text", :null=>false

          index [:name], :unique=>true
        end

        create_table(:runtime_configs) do
          primary_key :id
          column :properties, "text"
          column :created_at, "timestamp without time zone", :null=>false
          column :name, "text", :default=>"", :null=>false

          index [:created_at]
        end

        create_table(:stemcell_uploads) do
          primary_key :id
          column :name, "text"
          column :version, "text"
          column :cpi, "text"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:stemcells) do
          primary_key :id
          column :name, "text", :null=>false
          column :version, "text", :null=>false
          column :cid, "text", :null=>false
          column :sha1, "text"
          column :operating_system, "text"
          column :cpi, "text", :default=>""
          column :api_version, "integer"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:tasks) do
          primary_key :id
          column :state, "text", :null=>false
          column :timestamp, "timestamp without time zone", :null=>false
          column :description, "text", :null=>false
          column :result, "text"
          column :output, "text"
          column :checkpoint_time, "timestamp without time zone"
          column :type, "text", :null=>false
          column :username, "text"
          column :deployment_name, "text"
          column :started_at, "timestamp without time zone"
          column :event_output, "text"
          column :result_output, "text"
          column :context_id, "character varying(64)", :default=>"", :null=>false

          index [:context_id]
          index [:description]
          index [:state]
          index [:timestamp]
          index [:type]
        end

        create_table(:teams) do
          primary_key :id
          column :name, "text", :null=>false

          index [:name],:unique=>true
        end

        create_table(:deployment_problems) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id]
          column :state, "text", :null=>false
          column :resource_id, "integer", :null=>false
          column :type, "text", :null=>false
          column :data_json, "text", :null=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :last_seen_at, "timestamp without time zone", :null=>false
          column :counter, "integer", :default=>0, :null=>false

          index [:deployment_id, :state, :created_at]
          index [:deployment_id, :type, :state]
        end

        create_table(:deployment_properties) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id]
          column :name, "text", :null=>false
          column :value, "text", :null=>false

          index [:deployment_id, :name], :unique=>true
        end

        create_table(:deployments_configs) do
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :config_id, :configs, :null=>false, :key=>[:id], :on_delete=>:cascade

          index [:deployment_id, :config_id], :unique=>true
        end

        create_table(:deployments_networks) do
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :network_id, :networks, :null=>false, :key=>[:id], :on_delete=>:cascade

          index [:deployment_id, :network_id], :unique=>true
        end

        create_table(:deployments_stemcells) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id]
          foreign_key :stemcell_id, :stemcells, :null=>false, :key=>[:id]

          index [:deployment_id, :stemcell_id], :unique=>true
        end

        create_table(:deployments_teams) do
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :team_id, :teams, :null=>false, :key=>[:id], :on_delete=>:cascade

          index [:deployment_id, :team_id], :unique=>true
        end

        create_table(:errand_runs) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :default=>Sequel::LiteralString.new("'-1'::integer"), :null=>false, :key=>[:id], :on_delete=>:cascade
          column :errand_name, "text"
          column :successful_state_hash, "character varying(512)"
        end

        create_table(:link_consumers) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :key=>[:id], :on_delete=>:cascade
          column :instance_group, "text"
          column :name, "text", :null=>false
          column :type, "text", :null=>false
          column :serial_id, "integer"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_consumers_constraint, :unique=>true
        end

        create_table(:link_providers) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          column :instance_group, "text", :null=>false
          column :name, "text", :null=>false
          column :type, "text", :null=>false
          column :serial_id, "integer"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_providers_constraint, :unique=>true
        end

        create_table(:local_dns_aliases) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :key=>[:id], :on_delete=>:cascade
          column :domain, "text"
          column :health_filter, "text"
          column :initial_health_check, "text"
          column :group_id, "text"
          column :placeholder_type, "text"
        end

        create_table(:local_dns_blobs) do
          primary_key :id, :type=>:Bignum
          foreign_key :blob_id, :blobs, :key=>[:id]
          column :version, "bigint"
          column :created_at, "timestamp without time zone"
          column :records_version, "integer", :default=>0, :null=>false
          column :aliases_version, "integer", :default=>0, :null=>false
        end

        create_table(:local_dns_encoded_groups) do
          primary_key :id
          column :name, "text", :null=>false
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          column :type, "text", :default=>"instance-group", :null=>false

          index [:name, :type, :deployment_id], :unique=>true
        end

        create_table(:orphan_snapshots) do
          primary_key :id
          foreign_key :orphan_disk_id, :orphan_disks, :null=>false, :key=>[:id]
          column :snapshot_cid, "text", :null=>false
          column :clean, "boolean", :default=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :snapshot_created_at, "timestamp without time zone"

          index [:created_at]
          index [:snapshot_cid], :unique=>true
        end

        create_table(:packages) do
          primary_key :id
          column :name, "text", :null=>false
          column :version, "text", :null=>false
          column :blobstore_id, "text"
          column :sha1, "text"
          column :dependency_set_json, "text", :null=>false
          foreign_key :release_id, :releases, :null=>false, :key=>[:id]
          column :fingerprint, "text"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:release_versions) do
          primary_key :id
          column :version, "text", :null=>false
          foreign_key :release_id, :releases, :null=>false, :key=>[:id]
          column :commit_hash, "text", :default=>"unknown"
          column :uncommitted_changes, "boolean", :default=>false
          column :update_completed, "boolean", :default=>false, :null=>false
        end

        create_table(:subnets) do
          primary_key :id
          column :cid, "text", :null=>false
          column :name, "text", :null=>false
          column :range, "text"
          column :gateway, "text"
          column :reserved, "text"
          column :cloud_properties, "text"
          column :cpi, "text", :default=>""
          foreign_key :network_id, :networks, :null=>false, :key=>[:id], :on_delete=>:cascade
        end

        create_table(:tasks_teams) do
          foreign_key :task_id, :tasks, :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :team_id, :teams, :null=>false, :key=>[:id], :on_delete=>:cascade

          index [:task_id, :team_id], :unique=>true
        end

        create_table(:templates) do
          primary_key :id
          column :name, "text", :null=>false
          column :version, "text", :null=>false
          column :blobstore_id, "text", :null=>false
          column :sha1, "text", :null=>false
          column :package_names_json, "text", :null=>false
          foreign_key :release_id, :releases, :null=>false, :key=>[:id]
          column :fingerprint, "text"
          column :spec_json, "text"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:variable_sets) do
          primary_key :id, :type=>:Bignum
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id], :on_delete=>:cascade
          column :created_at, "timestamp without time zone", :null=>false
          column :deployed_successfully, "boolean", :default=>false
          column :writable, "boolean", :default=>false

          index [:created_at]
        end

        create_table(:compiled_packages) do
          primary_key :id
          column :blobstore_id, "text", :null=>false
          column :sha1, "text", :null=>false
          column :dependency_key, "text", :null=>false
          column :build, "integer", :null=>false
          foreign_key :package_id, :packages, :null=>false, :key=>[:id]
          column :dependency_key_sha1, "text", :null=>false
          column :stemcell_os, "text"
          column :stemcell_version, "text"

          index [:package_id, :stemcell_os, :stemcell_version, :build], :name=>:package_stemcell_build_idx, :unique=>true
          index [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1], :name=>:package_stemcell_dependency_idx, :unique=>true
        end

        create_table(:deployments_release_versions) do
          primary_key :id
          foreign_key :release_version_id, :release_versions, :null=>false, :key=>[:id]
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id]

          index [:release_version_id, :deployment_id], :unique=>true
        end

        create_table(:instances) do
          primary_key :id
          column :job, "text", :null=>false
          column :index, "integer", :null=>false
          foreign_key :deployment_id, :deployments, :null=>false, :key=>[:id]
          column :state, "text", :null=>false
          column :uuid, "text"
          column :availability_zone, "text"
          column :cloud_properties, "text"
          column :compilation, "boolean", :default=>false
          column :bootstrap, "boolean", :default=>false
          column :dns_records, "text"
          column :spec_json, "text"
          column :vm_cid_bak, "text"
          column :agent_id_bak, "text"
          column :trusted_certs_sha1_bak, "text", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :update_completed, "boolean", :default=>false
          column :ignore, "boolean", :default=>false
          foreign_key :variable_set_id, :variable_sets, :type=>"bigint", :null=>false, :key=>[:id]

          index [:agent_id_bak], :unique=>true
          index [:uuid], :unique=>true
          index [:vm_cid_bak], :unique=>true
        end

        create_table(:link_consumer_intents) do
          primary_key :id
          foreign_key :link_consumer_id, :link_consumers, :key=>[:id], :on_delete=>:cascade
          column :original_name, "text", :null=>false
          column :type, "text", :null=>false
          column :name, "text"
          column :optional, "boolean", :default=>false, :null=>false
          column :blocked, "boolean", :default=>false, :null=>false
          column :metadata, "text"
          column :serial_id, "integer"

          index [:link_consumer_id, :original_name], :name=>:link_consumer_intents_constraint, :unique=>true
        end

        create_table(:link_provider_intents) do
          primary_key :id
          foreign_key :link_provider_id, :link_providers, :key=>[:id], :on_delete=>:cascade
          column :original_name, "text", :null=>false
          column :type, "text", :null=>false
          column :name, "text"
          column :content, "text"
          column :shared, "boolean", :default=>false, :null=>false
          column :consumable, "boolean", :default=>true, :null=>false
          column :metadata, "text"
          column :serial_id, "integer"

          index [:link_provider_id, :original_name], :name=>:link_provider_intents_constraint, :unique=>true
        end

        create_table(:packages_release_versions) do
          primary_key :id
          foreign_key :package_id, :packages, :null=>false, :key=>[:id]
          foreign_key :release_version_id, :release_versions, :null=>false, :key=>[:id]

          index [:package_id, :release_version_id], :unique=>true
        end

        create_table(:release_versions_templates) do
          primary_key :id
          foreign_key :release_version_id, :release_versions, :null=>false, :key=>[:id]
          foreign_key :template_id, :templates, :null=>false, :key=>[:id]

          index [:release_version_id, :template_id], :unique=>true
        end

        create_table(:variables) do
          primary_key :id, :type=>:Bignum
          column :variable_id, "text", :null=>false
          column :variable_name, "text", :null=>false
          foreign_key :variable_set_id, :variable_sets, :type=>"bigint", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :is_local, "boolean", :default=>true
          column :provider_deployment, "text", :default=>""

          index [:variable_set_id, :variable_name, :provider_deployment], :name=>:variable_set_name_provider_idx, :unique=>true
        end

        create_table(:instances_templates) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false, :key=>[:id]
          foreign_key :template_id, :templates, :null=>false, :key=>[:id]

          index [:instance_id, :template_id], :unique=>true
        end

        create_table(:links) do
          primary_key :id
          foreign_key :link_provider_intent_id, :link_provider_intents, :key=>[:id], :on_delete=>:set_null
          foreign_key :link_consumer_intent_id, :link_consumer_intents, :null=>false, :key=>[:id], :on_delete=>:cascade
          column :name, "text", :null=>false
          column :link_content, "text"
          column :created_at, "timestamp without time zone"
        end

        create_table(:local_dns_records) do
          primary_key :id, :type=>:Bignum
          column :ip, "text", :null=>false
          column :az, "text"
          column :instance_group, "text"
          column :network, "text"
          column :deployment, "text"
          foreign_key :instance_id, :instances, :key=>[:id]
          column :agent_id, "text"
          column :domain, "text"
          column :links_json, "text"
        end

        create_table(:persistent_disks) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false, :key=>[:id]
          column :disk_cid, "text", :null=>false
          column :size, "integer"
          column :active, "boolean", :default=>false
          column :cloud_properties_json, "text"
          column :name, "text", :default=>""
          column :cpi, "text", :default=>""

          index [:disk_cid], :unique=>true
        end

        create_table(:rendered_templates_archives) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false, :key=>[:id]
          column :blobstore_id, "text", :null=>false
          column :sha1, "text", :null=>false
          column :content_sha1, "text", :null=>false
          column :created_at, "timestamp without time zone", :null=>false

          index [:created_at]
        end

        create_table(:vms) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false, :key=>[:id]
          column :agent_id, "text"
          column :cid, "text"
          column :trusted_certs_sha1, "text", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :active, "boolean", :default=>false
          column :cpi, "text", :default=>""
          column :created_at, "timestamp without time zone"
          column :network_spec_json, "text"
          column :stemcell_api_version, "integer"
          column :stemcell_name, "text"
          column :stemcell_version, "text"
          column :env_json, "text"
          column :cloud_properties_json, "text"

          index [:agent_id], :unique=>true
          index [:cid], :unique=>true
        end

        create_table(:instances_links) do
          primary_key :id
          foreign_key :link_id, :links, :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :instance_id, :instances, :null=>false, :key=>[:id], :on_delete=>:cascade
          column :serial_id, "integer"

          index [:link_id, :instance_id], :unique=>true
        end

        create_table(:ip_addresses) do
          primary_key :id
          column :network_name, "text"
          column :static, "boolean"
          foreign_key :instance_id, :instances, :key=>[:id]
          column :created_at, "timestamp without time zone"
          column :task_id, "text"
          column :address_str, "text", :null=>false
          foreign_key :vm_id, :vms, :key=>[:id]
          column :orphaned_vm_id, "integer"

          index [:address_str], :unique=>true
        end

        create_table(:snapshots) do
          primary_key :id
          foreign_key :persistent_disk_id, :persistent_disks, :null=>false, :key=>[:id]
          column :clean, "boolean", :default=>false
          column :created_at, "timestamp without time zone", :null=>false
          column :snapshot_cid, "text", :null=>false

          index [:snapshot_cid], :unique=>true
        end
      end

    when :mysql2
      begin
        create_table(:agent_dns_versions) do
          primary_key :id, :type=>:Bignum
          column :agent_id, "varchar(255)", :null=>false
          column :dns_version, "bigint", :default=>0, :null=>false

          index [:agent_id], :unique=>true
        end

        create_table(:blobs) do
          primary_key :id, :type=>"int"
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(512)", :null=>false
          column :created_at, "datetime", :null=>false
          column :type, "varchar(255)"
        end

        create_table(:cloud_configs) do
          primary_key :id, :type=>"int"
          column :properties, "longtext"
          column :created_at, "datetime", :null=>false

          index [:created_at]
        end

        create_table(:configs) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :content, "longtext", :null=>false
          column :created_at, "datetime", :null=>false
          column :deleted, "tinyint(1)", :default=>false
          column :team_id, "int"
        end

        create_table(:cpi_configs) do
          primary_key :id, :type=>"int"
          column :properties, "longtext"
          column :created_at, "datetime", :null=>false

          index [:created_at]
        end

        create_table(:delayed_jobs) do
          primary_key :id, :type=>"int"
          column :priority, "int", :default=>0, :null=>false
          column :attempts, "int", :default=>0, :null=>false
          column :handler, "longtext", :null=>false
          column :last_error, "longtext"
          column :run_at, "datetime"
          column :locked_at, "datetime"
          column :failed_at, "datetime"
          column :locked_by, "varchar(255)"
          column :queue, "varchar(255)"

          index [:priority, :run_at]
        end

        create_table(:deployments) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :manifest, "longtext"
          column :manifest_text, "longtext"
          column :has_stale_errand_links, "tinyint(1)", :default=>false, :null=>false
          column :links_serial_id, "int", :default=>0

          index [:name], :unique=>true
        end

        create_table(:director_attributes) do
          column :value, "longtext"
          column :name, "varchar(255)", :null=>false
          primary_key :id, :type=>"int", :keep_order=>true

          index [:name], :unique=>true
        end

        create_table(:events) do
          primary_key :id, :type=>:Bignum
          column :parent_id, "bigint"
          column :user, "varchar(255)", :null=>false
          column :timestamp, "datetime", :null=>false
          column :action, "varchar(255)", :null=>false
          column :object_type, "varchar(255)", :null=>false
          column :object_name, "varchar(255)"
          column :error, "longtext"
          column :task, "varchar(255)"
          column :deployment, "varchar(255)"
          column :instance, "varchar(255)"
          column :context_json, "longtext"

          index [:timestamp]
        end

        create_table(:local_dns_encoded_azs) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:local_dns_encoded_networks) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:locks) do
          primary_key :id, :type=>"int"
          column :expired_at, "datetime", :null=>false
          column :name, "varchar(255)", :null=>false
          column :uid, "varchar(255)", :null=>false
          column :task_id, "varchar(255)", :default=>"", :null=>false

          index [:name], :unique=>true
          index [:uid], :unique=>true
        end

        create_table(:log_bundles) do
          primary_key :id, :type=>"int"
          column :blobstore_id, "varchar(255)", :null=>false
          column :timestamp, "datetime", :null=>false

          index [:blobstore_id], :unique=>true
          index [:timestamp]
        end

        create_table(:networks) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :created_at, "datetime", :null=>false
          column :orphaned, "tinyint(1)", :default=>false
          column :orphaned_at, "datetime"

          index [:name], :unique=>true
        end

        create_table(:orphan_disks) do
          primary_key :id, :type=>"int"
          column :disk_cid, "varchar(255)", :null=>false
          column :size, "int"
          column :availability_zone, "varchar(255)"
          column :deployment_name, "varchar(255)", :null=>false
          column :instance_name, "varchar(255)", :null=>false
          column :cloud_properties_json, "longtext"
          column :created_at, "datetime", :null=>false
          column :cpi, "varchar(255)", :default=>""

          index [:disk_cid], :unique=>true
          index [:created_at]
        end

        create_table(:orphaned_vms) do
          primary_key :id, :type=>"int"
          column :cid, "varchar(255)", :null=>false
          column :availability_zone, "varchar(255)"
          column :cloud_properties, "longtext"
          column :cpi, "varchar(255)"
          column :orphaned_at, "datetime", :null=>false
          column :stemcell_api_version, "int"
          column :deployment_name, "varchar(255)"
          column :instance_name, "varchar(255)"
        end

        create_table(:releases) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:runtime_configs) do
          primary_key :id, :type=>"int"
          column :properties, "longtext"
          column :created_at, "datetime", :null=>false
          column :name, "varchar(255)", :default=>"", :null=>false

          index [:created_at]
        end

        create_table(:stemcell_uploads) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)"
          column :version, "varchar(255)"
          column :cpi, "varchar(255)"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:stemcells) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :cid, "varchar(255)", :null=>false
          column :sha1, "varchar(512)"
          column :operating_system, "varchar(255)"
          column :cpi, "varchar(255)", :default=>""
          column :api_version, "int"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:tasks) do
          primary_key :id, :type=>"int"
          column :state, "varchar(255)", :null=>false
          column :timestamp, "datetime", :null=>false
          column :description, "varchar(255)", :null=>false
          column :result, "longtext"
          column :output, "varchar(255)"
          column :checkpoint_time, "datetime"
          column :type, "varchar(255)", :null=>false
          column :username, "varchar(255)"
          column :deployment_name, "varchar(255)"
          column :started_at, "datetime"
          column :event_output, "longtext"
          column :result_output, "longtext"
          column :context_id, "varchar(64)", :default=>"", :null=>false

          index [:context_id]
          index [:description]
          index [:state]
          index [:timestamp]
          index [:type]
        end

        create_table(:teams) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:deployment_problems) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id]
          column :state, "varchar(255)", :null=>false
          column :resource_id, "int", :null=>false
          column :type, "varchar(255)", :null=>false
          column :data_json, "longtext", :null=>false
          column :created_at, "datetime", :null=>false
          column :last_seen_at, "datetime", :null=>false
          column :counter, "int", :default=>0, :null=>false

          index [:deployment_id, :state, :created_at]
          index [:deployment_id, :type, :state]
        end

        create_table(:deployment_properties) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id]
          column :name, "varchar(255)", :null=>false
          column :value, "longtext", :null=>false

          index [:deployment_id, :name], :unique=>true
        end

        create_table(:deployments_configs) do
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :config_id, :configs, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade

          primary_key [:deployment_id, :config_id]

          index [:config_id]
          index [:deployment_id, :config_id], :unique=>true
        end

        create_table(:deployments_networks) do
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :network_id, :networks, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade

          primary_key [:deployment_id, :network_id]

          index [:deployment_id, :network_id], :unique=>true
          index [:network_id]
        end

        create_table(:deployments_stemcells) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id]
          foreign_key :stemcell_id, :stemcells, :type=>"int", :null=>false, :key=>[:id]

          index [:deployment_id, :stemcell_id], :unique=>true
          index [:stemcell_id]
        end

        create_table(:deployments_teams) do
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :team_id, :teams, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade

          primary_key [:deployment_id, :team_id]

          index [:deployment_id, :team_id], :unique=>true
          index [:team_id]
        end

        create_table(:errand_runs) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :default=>-1, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :errand_name, "longtext"
          column :successful_state_hash, "varchar(512)"

          index [:deployment_id]
        end

        create_table(:link_consumers) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :key=>[:id], :on_delete=>:cascade
          column :instance_group, "varchar(255)"
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :serial_id, "int"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_consumers_constraint, :unique=>true
        end

        create_table(:link_providers) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :instance_group, "varchar(255)", :null=>false
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :serial_id, "int"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_providers_constraint, :unique=>true
        end

        create_table(:local_dns_aliases) do
          primary_key :id, :type=>"int"
          foreign_key :deployment_id, :deployments, :type=>"int", :key=>[:id], :on_delete=>:cascade
          column :domain, "varchar(255)"
          column :health_filter, "varchar(255)"
          column :initial_health_check, "varchar(255)"
          column :group_id, "varchar(255)"
          column :placeholder_type, "varchar(255)"

          index [:deployment_id]
        end

        create_table(:local_dns_blobs) do
          primary_key :id, :type=>:Bignum
          foreign_key :blob_id, :blobs, :type=>"int", :key=>[:id]
          column :version, "bigint"
          column :created_at, "datetime"
          column :records_version, "int", :default=>0, :null=>false
          column :aliases_version, "int", :default=>0, :null=>false
        end

        create_table(:local_dns_encoded_groups) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :type, "varchar(255)", :default=>"instance-group", :null=>false

          index [:deployment_id]
          index [:name, :type, :deployment_id], :unique=>true
        end

        create_table(:orphan_snapshots) do
          primary_key :id, :type=>"int"
          foreign_key :orphan_disk_id, :orphan_disks, :type=>"int", :null=>false, :key=>[:id]
          column :snapshot_cid, "varchar(255)", :null=>false
          column :clean, "tinyint(1)", :default=>false
          column :created_at, "datetime", :null=>false
          column :snapshot_created_at, "datetime"

          index [:created_at]
          index [:orphan_disk_id]
          index [:snapshot_cid], :unique=>true
        end

        create_table(:packages) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :blobstore_id, "varchar(255)"
          column :sha1, "varchar(512)"
          column :dependency_set_json, "longtext", :null=>false
          foreign_key :release_id, :releases, :type=>"int", :null=>false, :key=>[:id]
          column :fingerprint, "varchar(255)"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:release_versions) do
          primary_key :id, :type=>"int"
          column :version, "varchar(255)", :null=>false
          foreign_key :release_id, :releases, :type=>"int", :null=>false, :key=>[:id]
          column :commit_hash, "varchar(255)", :default=>"unknown"
          column :uncommitted_changes, "tinyint(1)", :default=>false
          column :update_completed, "tinyint(1)", :default=>false, :null=>false

          index [:release_id]
        end

        create_table(:subnets) do
          primary_key :id, :type=>"int"
          column :cid, "varchar(255)", :null=>false
          column :name, "varchar(255)", :null=>false
          column :range, "varchar(255)"
          column :gateway, "varchar(255)"
          column :reserved, "varchar(255)"
          column :cloud_properties, "varchar(255)"
          column :cpi, "varchar(255)", :default=>""
          foreign_key :network_id, :networks, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade

          index [:network_id]
        end

        create_table(:tasks_teams) do
          foreign_key :task_id, :tasks, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :team_id, :teams, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade

          primary_key [:task_id, :team_id]

          index [:task_id, :team_id], :unique=>true
          index [:team_id]
        end

        create_table(:templates) do
          primary_key :id, :type=>"int"
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(512)", :null=>false
          column :package_names_json, "longtext", :null=>false
          foreign_key :release_id, :releases, :type=>"int", :null=>false, :key=>[:id]
          column :fingerprint, "varchar(255)"
          column :spec_json, "longtext"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:variable_sets) do
          primary_key :id, :type=>:Bignum
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :created_at, "datetime", :null=>false
          column :deployed_successfully, "tinyint(1)", :default=>false
          column :writable, "tinyint(1)", :default=>false

          index [:created_at]
          index [:deployment_id]
        end

        create_table(:compiled_packages) do
          primary_key :id, :type=>"int"
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(512)", :null=>false
          column :dependency_key, "longtext", :null=>false
          column :build, "int", :null=>false
          foreign_key :package_id, :packages, :type=>"int", :null=>false, :key=>[:id]
          column :dependency_key_sha1, "varchar(255)", :null=>false
          column :stemcell_os, "varchar(255)"
          column :stemcell_version, "varchar(255)"

          index [:package_id, :stemcell_os, :stemcell_version, :build], :name=>:package_stemcell_build_idx, :unique=>true
          index [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1], :name=>:package_stemcell_dependency_idx, :unique=>true
        end

        create_table(:deployments_release_versions) do
          primary_key :id, :type=>"int"
          foreign_key :release_version_id, :release_versions, :type=>"int", :null=>false, :key=>[:id]
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id]

          index [:deployment_id]
          index [:release_version_id, :deployment_id], :name=>:release_version_id, :unique=>true
        end

        create_table(:instances) do
          primary_key :id, :type=>"int"
          column :job, "varchar(255)", :null=>false
          column :index, "int", :null=>false
          foreign_key :deployment_id, :deployments, :type=>"int", :null=>false, :key=>[:id]
          column :state, "varchar(255)", :null=>false
          column :uuid, "varchar(255)"
          column :availability_zone, "varchar(255)"
          column :cloud_properties, "longtext"
          column :compilation, "tinyint(1)", :default=>false
          column :bootstrap, "tinyint(1)", :default=>false
          column :dns_records, "longtext"
          column :spec_json, "longtext"
          column :vm_cid_bak, "varchar(255)"
          column :agent_id_bak, "varchar(255)"
          column :trusted_certs_sha1_bak, "varchar(255)", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :update_completed, "tinyint(1)", :default=>false
          column :ignore, "tinyint(1)", :default=>false
          foreign_key :variable_set_id, :variable_sets, :type=>"bigint", :null=>false, :key=>[:id]

          index [:agent_id_bak], :unique=>true
          index [:deployment_id]
          index [:uuid], :unique=>true
          index [:variable_set_id]
          index [:vm_cid_bak], :unique=>true
        end

        create_table(:link_consumer_intents) do
          primary_key :id, :type=>"int"
          foreign_key :link_consumer_id, :link_consumers, :type=>"int", :key=>[:id], :on_delete=>:cascade
          column :original_name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :name, "varchar(255)"
          column :optional, "tinyint(1)", :default=>false, :null=>false
          column :blocked, "tinyint(1)", :default=>false, :null=>false
          column :metadata, "longtext"
          column :serial_id, "int"

          index [:link_consumer_id, :original_name], :name=>:link_consumer_intents_constraint, :unique=>true
        end

        create_table(:link_provider_intents) do
          primary_key :id, :type=>"int"
          foreign_key :link_provider_id, :link_providers, :type=>"int", :key=>[:id], :on_delete=>:cascade
          column :original_name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :name, "varchar(255)"
          column :content, "longtext"
          column :shared, "tinyint(1)", :default=>false, :null=>false
          column :consumable, "tinyint(1)", :default=>true, :null=>false
          column :metadata, "longtext"
          column :serial_id, "int"

          index [:link_provider_id, :original_name], :name=>:link_provider_intents_constraint, :unique=>true
        end

        create_table(:packages_release_versions) do
          primary_key :id, :type=>"int"
          foreign_key :package_id, :packages, :type=>"int", :null=>false, :key=>[:id]
          foreign_key :release_version_id, :release_versions, :type=>"int", :null=>false, :key=>[:id]

          index [:package_id, :release_version_id], :unique=>true
          index [:release_version_id]
        end

        create_table(:release_versions_templates) do
          primary_key :id, :type=>"int"
          foreign_key :release_version_id, :release_versions, :type=>"int", :null=>false, :key=>[:id]
          foreign_key :template_id, :templates, :type=>"int", :null=>false, :key=>[:id]

          index [:release_version_id, :template_id], :unique=>true
          index [:template_id]
        end

        create_table(:variables) do
          primary_key :id, :type=>:Bignum
          column :variable_id, "varchar(255)", :null=>false
          column :variable_name, "varchar(255)", :null=>false
          foreign_key :variable_set_id, :variable_sets, :type=>"bigint", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :is_local, "tinyint(1)", :default=>true
          column :provider_deployment, "varchar(255)", :default=>""

          index [:variable_set_id, :variable_name, :provider_deployment], :name=>:variable_set_name_provider_idx, :unique=>true
        end

        create_table(:instances_templates) do
          primary_key :id, :type=>"int"
          foreign_key :instance_id, :instances, :type=>"int", :null=>false, :key=>[:id]
          foreign_key :template_id, :templates, :type=>"int", :null=>false, :key=>[:id]

          index [:instance_id, :template_id], :unique=>true
          index [:template_id]
        end

        create_table(:links) do
          primary_key :id, :type=>"int"
          foreign_key :link_provider_intent_id, :link_provider_intents, :type=>"int", :key=>[:id], :on_delete=>:set_null
          foreign_key :link_consumer_intent_id, :link_consumer_intents, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :name, "varchar(255)", :null=>false
          column :link_content, "longtext"
          column :created_at, "datetime"

          index [:link_consumer_intent_id]
          index [:link_provider_intent_id]
        end

        create_table(:local_dns_records) do
          primary_key :id, :type=>:Bignum
          column :ip, "varchar(255)", :null=>false
          column :az, "varchar(255)"
          column :instance_group, "varchar(255)"
          column :network, "varchar(255)"
          column :deployment, "varchar(255)"
          foreign_key :instance_id, :instances, :type=>"int", :key=>[:id]
          column :agent_id, "varchar(255)"
          column :domain, "varchar(255)"
          column :links_json, "longtext"

          index [:instance_id]
        end

        create_table(:persistent_disks) do
          primary_key :id, :type=>"int"
          foreign_key :instance_id, :instances, :type=>"int", :null=>false, :key=>[:id]
          column :disk_cid, "varchar(255)", :null=>false
          column :size, "int"
          column :active, "tinyint(1)", :default=>false
          column :cloud_properties_json, "longtext"
          column :name, "varchar(255)", :default=>""
          column :cpi, "varchar(255)", :default=>""

          index [:disk_cid], :unique=>true
          index [:instance_id]
        end

        create_table(:rendered_templates_archives) do
          primary_key :id, :type=>"int"
          foreign_key :instance_id, :instances, :type=>"int", :null=>false, :key=>[:id]
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(255)", :null=>false
          column :content_sha1, "varchar(255)", :null=>false
          column :created_at, "datetime", :null=>false

          index [:created_at]
          index [:instance_id]
        end

        create_table(:vms) do
          primary_key :id, :type=>"int"
          foreign_key :instance_id, :instances, :type=>"int", :null=>false, :key=>[:id]
          column :agent_id, "varchar(255)"
          column :cid, "varchar(255)"
          column :trusted_certs_sha1, "varchar(255)", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :active, "tinyint(1)", :default=>false
          column :cpi, "varchar(255)", :default=>""
          column :created_at, "datetime"
          column :network_spec_json, "longtext"
          column :stemcell_api_version, "int"
          column :stemcell_name, "varchar(255)"
          column :stemcell_version, "varchar(255)"
          column :env_json, "longtext"
          column :cloud_properties_json, "longtext"

          index [:agent_id], :unique=>true
          index [:cid], :unique=>true
          index [:instance_id]
        end

        create_table(:instances_links) do
          primary_key :id, :type=>"int"
          foreign_key :link_id, :links, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          foreign_key :instance_id, :instances, :type=>"int", :null=>false, :key=>[:id], :on_delete=>:cascade
          column :serial_id, "int"

          index [:instance_id]
          index [:link_id, :instance_id], :unique=>true
        end

        create_table(:ip_addresses) do
          primary_key :id, :type=>"int"
          column :network_name, "varchar(255)"
          column :static, "tinyint(1)"
          foreign_key :instance_id, :instances, :type=>"int", :key=>[:id]
          column :created_at, "datetime"
          column :task_id, "varchar(255)"
          column :address_str, "varchar(255)", :null=>false
          foreign_key :vm_id, :vms, :type=>"int", :key=>[:id]
          column :orphaned_vm_id, "int"

          index [:address_str], :unique=>true
          index [:instance_id]
          index [:vm_id]
        end

        create_table(:snapshots) do
          primary_key :id, :type=>"int"
          foreign_key :persistent_disk_id, :persistent_disks, :type=>"int", :null=>false, :key=>[:id]
          column :clean, "tinyint(1)", :default=>false
          column :created_at, "datetime", :null=>false
          column :snapshot_cid, "varchar(255)", :null=>false

          index [:persistent_disk_id]
          index [:snapshot_cid], :unique=>true
        end
      end

    when :sqlite
      begin
        create_table(:agent_dns_versions) do
          primary_key :id
          column :agent_id, "varchar(255)", :null=>false
          column :dns_version, "INTEGER", :default=>0, :null=>false

          index [:agent_id], :unique=>true
        end

        create_table(:blobs) do
          primary_key :id
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(255)", :null=>false
          column :created_at, "timestamp", :null=>false
          column :type, "varchar(255)"
        end

        create_table(:cloud_configs) do
          primary_key :id
          column :properties, "TEXT"
          column :created_at, "timestamp", :null=>false

          index [:created_at]
        end

        create_table(:configs) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :content, "TEXT", :null=>false
          column :created_at, "timestamp", :null=>false
          column :deleted, "boolean", :default=>false
          column :team_id, "INTEGER"
        end

        create_table(:cpi_configs) do
          primary_key :id
          column :properties, "TEXT"
          column :created_at, "timestamp", :null=>false

          index [:created_at]
        end

        create_table(:delayed_jobs) do
          primary_key :id
          column :priority, "INTEGER", :default=>0, :null=>false
          column :attempts, "INTEGER", :default=>0, :null=>false
          column :handler, "TEXT", :null=>false
          column :last_error, "TEXT"
          column :run_at, "timestamp"
          column :locked_at, "timestamp"
          column :failed_at, "timestamp"
          column :locked_by, "varchar(255)"
          column :queue, "varchar(255)"

          index [:priority, :run_at]
        end

        create_table(:deployments) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :manifest, "TEXT"
          column :manifest_text, "TEXT"
          column :has_stale_errand_links, "boolean", :default=>false, :null=>false
          column :links_serial_id, "INTEGER", :default=>0

          index [:name], :unique=>true
        end

        create_table(:director_attributes) do
          column :value, "TEXT"
          column :name, "varchar(255)", :null=>false
          primary_key :id, :keep_order=>true

          index [:name], :unique=>true
        end

        create_table(:events) do
          primary_key :id
          column :parent_id, "INTEGER"
          column :user, "varchar(255)", :null=>false
          column :timestamp, "timestamp", :null=>false
          column :action, "varchar(255)", :null=>false
          column :object_type, "varchar(255)", :null=>false
          column :object_name, "varchar(255)"
          column :error, "TEXT"
          column :task, "varchar(255)"
          column :deployment, "varchar(255)"
          column :instance, "varchar(255)"
          column :context_json, "TEXT"

          index [:timestamp]
        end

        create_table(:local_dns_encoded_azs) do
          primary_key :id
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:local_dns_encoded_networks) do
          primary_key :id
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:locks) do
          primary_key :id
          column :expired_at, "timestamp", :null=>false
          column :name, "varchar(255)", :null=>false
          column :uid, "varchar(255)", :null=>false
          column :task_id, "varchar(255)", :default=>"", :null=>false

          index [:name], :unique=>true
          index [:uid], :unique=>true
        end

        create_table(:log_bundles) do
          primary_key :id
          column :blobstore_id, "varchar(255)", :null=>false
          column :timestamp, "timestamp", :null=>false

          index [:blobstore_id], :unique=>true
          index [:timestamp]
        end

        create_table(:networks) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :created_at, "timestamp", :null=>false
          column :orphaned, "Boolean", :default=>false
          column :orphaned_at, "timestamp"

          index [:name], :unique=>true
        end

        create_table(:orphan_disks) do
          primary_key :id
          column :disk_cid, "varchar(255)", :null=>false
          column :size, "INTEGER"
          column :availability_zone, "varchar(255)"
          column :deployment_name, "varchar(255)", :null=>false
          column :instance_name, "varchar(255)", :null=>false
          column :cloud_properties_json, "TEXT"
          column :created_at, "timestamp", :null=>false
          column :cpi, "varchar(255)", :default=>""

          index [:disk_cid], :unique=>true
          index [:created_at]
        end

        create_table(:orphaned_vms) do
          primary_key :id
          column :cid, "varchar(255)", :null=>false
          column :availability_zone, "varchar(255)"
          column :cloud_properties, "TEXT"
          column :cpi, "varchar(255)"
          column :orphaned_at, "timestamp", :null=>false
          column :stemcell_api_version, "INTEGER"
          column :deployment_name, "varchar(255)"
          column :instance_name, "varchar(255)"
        end

        create_table(:releases) do
          primary_key :id
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:runtime_configs) do
          primary_key :id
          column :properties, "TEXT"
          column :created_at, "timestamp", :null=>false
          column :name, "varchar(255)", :default=>"", :null=>false

          index [:created_at]
        end

        create_table(:stemcell_uploads) do
          primary_key :id
          column :name, "varchar(255)"
          column :version, "varchar(255)"
          column :cpi, "varchar(255)"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:stemcells) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :cid, "varchar(255)", :null=>false
          column :sha1, "varchar(255)"
          column :operating_system, "varchar(255)"
          column :cpi, "varchar(255)", :default=>""
          column :api_version, "INTEGER"

          index [:name, :version, :cpi], :unique=>true
        end

        create_table(:tasks) do
          primary_key :id
          column :state, "varchar(255)", :null=>false
          column :timestamp, "timestamp", :null=>false
          column :description, "varchar(255)", :null=>false
          column :result, "TEXT"
          column :output, "varchar(255)"
          column :checkpoint_time, "timestamp"
          column :type, "varchar(255)", :null=>false
          column :username, "varchar(255)"
          column :deployment_name, "varchar(255)"
          column :started_at, "timestamp"
          column :event_output, "TEXT"
          column :result_output, "TEXT"
          column :context_id, "varchar(64)", :default=>"", :null=>false

          index [:context_id]
          index [:description]
          index [:state]
          index [:timestamp]
          index [:type]
        end

        create_table(:teams) do
          primary_key :id
          column :name, "varchar(255)", :null=>false

          index [:name], :unique=>true
        end

        create_table(:deployment_problems) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false
          column :state, "varchar(255)", :null=>false
          column :resource_id, "INTEGER", :null=>false
          column :type, "varchar(255)", :null=>false
          column :data_json, "TEXT", :null=>false
          column :created_at, "timestamp", :null=>false
          column :last_seen_at, "timestamp", :null=>false
          column :counter, "INTEGER", :default=>0, :null=>false

          index [:deployment_id, :state, :created_at]
          index [:deployment_id, :type, :state]
        end

        create_table(:deployment_properties) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false
          column :name, "varchar(255)", :null=>false
          column :value, "TEXT", :null=>false

          index [:deployment_id, :name], :unique=>true
        end

        create_table(:deployments_configs) do
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          foreign_key :config_id, :configs, :null=>false, :on_delete=>:cascade

          index [:deployment_id, :config_id], :unique=>true
        end

        create_table(:deployments_networks) do
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          foreign_key :network_id, :networks, :null=>false, :on_delete=>:cascade

          index [:deployment_id, :network_id], :unique=>true
        end

        create_table(:deployments_stemcells) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false
          foreign_key :stemcell_id, :stemcells, :null=>false

          index [:deployment_id, :stemcell_id], :unique=>true
        end

        create_table(:deployments_teams) do
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          foreign_key :team_id, :teams, :null=>false, :on_delete=>:cascade

          index [:deployment_id, :team_id], :unique=>true
        end

        create_table(:errand_runs) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :default=>-1, :null=>false, :on_delete=>:cascade
          column :errand_name, "TEXT"
          column :successful_state_hash, "varchar(512)"
        end

        create_table(:link_consumers) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :on_delete=>:cascade
          column :instance_group, "varchar(255)"
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :serial_id, "INTEGER"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_consumers_constraint, :unique=>true
        end

        create_table(:link_providers) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          column :instance_group, "varchar(255)", :null=>false
          column :name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :serial_id, "INTEGER"

          index [:deployment_id, :instance_group, :name, :type], :name=>:link_providers_constraint, :unique=>true
        end

        create_table(:local_dns_aliases) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :on_delete=>:cascade
          column :domain, "varchar(255)"
          column :health_filter, "varchar(255)"
          column :initial_health_check, "varchar(255)"
          column :group_id, "varchar(255)"
          column :placeholder_type, "varchar(255)"
        end

        create_table(:local_dns_blobs) do
          primary_key :id
          foreign_key :blob_id, :blobs
          column :version, "bigint"
          column :created_at, "timestamp"
          column :records_version, "INTEGER", :default=>0, :null=>false
          column :aliases_version, "INTEGER", :default=>0, :null=>false
        end

        create_table(:local_dns_encoded_groups) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          column :type, "varchar(255)", :default=>"instance-group", :null=>false

          index [:name, :type, :deployment_id], :unique=>true
        end

        create_table(:orphan_snapshots) do
          primary_key :id
          foreign_key :orphan_disk_id, :orphan_disks, :null=>false
          column :snapshot_cid, "varchar(255)", :null=>false
          column :clean, "Boolean", :default=>false
          column :created_at, "timestamp", :null=>false
          column :snapshot_created_at, "timestamp"

          index [:created_at]
          index [:snapshot_cid], :unique=>true
        end

        create_table(:packages) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :blobstore_id, "varchar(255)"
          column :sha1, "varchar(255)"
          column :dependency_set_json, "TEXT", :null=>false
          foreign_key :release_id, :releases, :null=>false
          column :fingerprint, "varchar(255)"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:release_versions) do
          primary_key :id
          column :version, "varchar(255)", :null=>false
          foreign_key :release_id, :releases, :null=>false
          column :commit_hash, "varchar(255)", :default=>"unknown"
          column :uncommitted_changes, "boolean", :default=>false
          column :update_completed, "boolean", :default=>false, :null=>false
        end

        create_table(:subnets) do
          primary_key :id
          column :cid, "varchar(255)", :null=>false
          column :name, "varchar(255)", :null=>false
          column :range, "varchar(255)"
          column :gateway, "varchar(255)"
          column :reserved, "varchar(255)"
          column :cloud_properties, "varchar(255)"
          column :cpi, "varchar(255)", :default=>""
          foreign_key :network_id, :networks, :null=>false, :on_delete=>:cascade
        end

        create_table(:tasks_teams) do
          foreign_key :task_id, :tasks, :null=>false, :on_delete=>:cascade
          foreign_key :team_id, :teams, :null=>false, :on_delete=>:cascade

          index [:task_id, :team_id], :unique=>true
        end

        create_table(:templates) do
          primary_key :id
          column :name, "varchar(255)", :null=>false
          column :version, "varchar(255)", :null=>false
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(255)", :null=>false
          column :package_names_json, "TEXT", :null=>false
          foreign_key :release_id, :releases, :null=>false
          column :fingerprint, "varchar(255)"
          column :spec_json, "varchar(255)"

          index [:fingerprint]
          index [:release_id, :name, :version], :unique=>true
          index [:sha1]
        end

        create_table(:variable_sets) do
          primary_key :id
          foreign_key :deployment_id, :deployments, :null=>false, :on_delete=>:cascade
          column :created_at, "timestamp", :null=>false
          column :deployed_successfully, "boolean", :default=>false
          column :writable, "boolean", :default=>false

          index [:created_at]
        end

        create_table(:compiled_packages) do
          primary_key :id
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(255)", :null=>false
          column :dependency_key, "TEXT", :null=>false
          column :build, "INTEGER", :null=>false
          foreign_key :package_id, :packages, :null=>false
          column :dependency_key_sha1, "varchar(255)", :null=>false
          column :stemcell_os, "varchar(255)"
          column :stemcell_version, "varchar(255)"

          index [:package_id, :stemcell_os, :stemcell_version, :build], :unique=>true
          index [:package_id, :stemcell_os, :stemcell_version, :dependency_key_sha1], :unique=>true
        end

        create_table(:deployments_release_versions) do
          primary_key :id
          foreign_key :release_version_id, :release_versions, :null=>false
          foreign_key :deployment_id, :deployments, :null=>false

          index [:release_version_id, :deployment_id], :unique=>true
        end

        create_table(:instances) do
          primary_key :id
          column :job, "varchar(255)", :null=>false
          column :index, "INTEGER", :null=>false
          foreign_key :deployment_id, :deployments, :null=>false
          column :state, "varchar(255)", :null=>false
          column :uuid, "varchar(255)"
          column :availability_zone, "varchar(255)"
          column :cloud_properties, "TEXT"
          column :compilation, "boolean", :default=>false
          column :bootstrap, "boolean", :default=>false
          column :dns_records, "TEXT"
          column :spec_json, "TEXT"
          column :vm_cid_bak, "varchar(255)"
          column :agent_id_bak, "varchar(255)"
          column :trusted_certs_sha1_bak, "varchar(255)", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :update_completed, "boolean", :default=>false
          column :ignore, "boolean", :default=>false
          foreign_key :variable_set_id, :variable_sets, :null=>false

          index [:agent_id_bak], :unique=>true
          index [:uuid], :unique=>true
          index [:vm_cid_bak], :unique=>true
        end

        create_table(:link_consumer_intents) do
          primary_key :id
          foreign_key :link_consumer_id, :link_consumers, :on_delete=>:cascade
          column :original_name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :name, "varchar(255)"
          column :optional, "Boolean", :default=>false, :null=>false
          column :blocked, "Boolean", :default=>false, :null=>false
          column :metadata, "varchar(255)"
          column :serial_id, "INTEGER"

          index [:link_consumer_id, :original_name], :name=>:link_consumer_intents_constraint, :unique=>true
        end

        create_table(:link_provider_intents) do
          primary_key :id
          foreign_key :link_provider_id, :link_providers, :on_delete=>:cascade
          column :original_name, "varchar(255)", :null=>false
          column :type, "varchar(255)", :null=>false
          column :name, "varchar(255)"
          column :content, "varchar(255)"
          column :shared, "Boolean", :default=>false, :null=>false
          column :consumable, "Boolean", :default=>true, :null=>false
          column :metadata, "varchar(255)"
          column :serial_id, "INTEGER"

          index [:link_provider_id, :original_name], :name=>:link_provider_intents_constraint, :unique=>true
        end

        create_table(:packages_release_versions) do
          primary_key :id
          foreign_key :package_id, :packages, :null=>false
          foreign_key :release_version_id, :release_versions, :null=>false

          index [:package_id, :release_version_id], :unique=>true
        end

        create_table(:release_versions_templates) do
          primary_key :id
          foreign_key :release_version_id, :release_versions, :null=>false
          foreign_key :template_id, :templates, :null=>false

          index [:release_version_id, :template_id], :unique=>true
        end

        create_table(:variables) do
          primary_key :id
          column :variable_id, "varchar(255)", :null=>false
          column :variable_name, "varchar(255)", :null=>false
          foreign_key :variable_set_id, :variable_sets, :null=>false, :on_delete=>:cascade
          column :is_local, "boolean", :default=>true
          column :provider_deployment, "varchar(255)", :default=>""

          index [:variable_set_id, :variable_name, :provider_deployment], :name=>:variable_set_name_provider_idx, :unique=>true
        end

        create_table(:instances_templates) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false
          foreign_key :template_id, :templates, :null=>false

          index [:instance_id, :template_id], :unique=>true
        end

        create_table(:links) do
          primary_key :id
          foreign_key :link_provider_intent_id, :link_provider_intents, :on_delete=>:set_null
          foreign_key :link_consumer_intent_id, :link_consumer_intents, :null=>false, :on_delete=>:cascade
          column :name, "varchar(255)", :null=>false
          column :link_content, "varchar(255)"
          column :created_at, "timestamp"
        end

        create_table(:local_dns_records) do
          primary_key :id
          column :ip, "varchar(255)", :null=>false
          column :az, "varchar(255)"
          column :instance_group, "varchar(255)"
          column :network, "varchar(255)"
          column :deployment, "varchar(255)"
          foreign_key :instance_id, :instances
          column :agent_id, "varchar(255)"
          column :domain, "varchar(255)"
          column :links_json, "TEXT"
        end

        create_table(:persistent_disks) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false
          column :disk_cid, "varchar(255)", :null=>false
          column :size, "INTEGER"
          column :active, "Boolean", :default=>false
          column :cloud_properties_json, "TEXT"
          column :name, "varchar(255)", :default=>""
          column :cpi, "varchar(255)", :default=>""

          index [:disk_cid], :unique=>true
        end

        create_table(:rendered_templates_archives) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false
          column :blobstore_id, "varchar(255)", :null=>false
          column :sha1, "varchar(255)", :null=>false
          column :content_sha1, "varchar(255)", :null=>false
          column :created_at, "timestamp", :null=>false

          index [:created_at]
        end

        create_table(:vms) do
          primary_key :id
          foreign_key :instance_id, :instances, :null=>false
          column :agent_id, "varchar(255)"
          column :cid, "varchar(255)"
          column :trusted_certs_sha1, "varchar(255)", :default=>"da39a3ee5e6b4b0d3255bfef95601890afd80709"
          column :active, "boolean", :default=>false
          column :cpi, "varchar(255)", :default=>""
          column :created_at, "timestamp"
          column :network_spec_json, "varchar(255)"
          column :stemcell_api_version, "INTEGER"
          column :stemcell_name, "varchar(255)"
          column :stemcell_version, "varchar(255)"
          column :env_json, "varchar(255)"
          column :cloud_properties_json, "varchar(255)"

          index [:agent_id], :unique=>true
          index [:cid], :unique=>true
        end

        create_table(:instances_links) do
          primary_key :id
          foreign_key :link_id, :links, :null=>false, :on_delete=>:cascade
          foreign_key :instance_id, :instances, :null=>false, :on_delete=>:cascade
          column :serial_id, "INTEGER"

          index [:link_id, :instance_id], :unique=>true
        end

        create_table(:ip_addresses) do
          primary_key :id
          column :network_name, "varchar(255)"
          column :static, "Boolean"
          foreign_key :instance_id, :instances
          column :created_at, "timestamp"
          column :task_id, "varchar(255)"
          column :address_str, "varchar(255)", :null=>false
          foreign_key :vm_id, :vms
          column :orphaned_vm_id, "INTEGER"

          index [:address_str], :unique=>true
        end

        create_table(:snapshots) do
          primary_key :id
          foreign_key :persistent_disk_id, :persistent_disks, :null=>false
          column :clean, "Boolean", :default=>false
          column :created_at, "timestamp", :null=>false
          column :snapshot_cid, "varchar(255)", :null=>false

          index [:snapshot_cid], :unique=>true
        end
      end

    else
      raise "Unknown adapter_scheme: #{adapter_scheme}"

    end
  end
end
