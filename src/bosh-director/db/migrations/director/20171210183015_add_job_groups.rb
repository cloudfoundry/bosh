Sequel.migration do
  up do
    create_table :delayed_job_groups do
      primary_key :group_id
      String :config_content, null: false
      Integer :limit
    end

    create_table :delayed_job_groups_jobs do
      foreign_key :job_id, :delayed_jobs, on_delete: :cascade, null: false
      foreign_key :delayed_job_group_id, :delayed_job_groups, on_delete: :cascade, null: false
      unique %i[job_id delayed_job_group_id]
    end

    set_column_type :delayed_job_groups, :config_content, 'longtext' if %i[mysql mysql2].include? adapter_scheme
  end
end
