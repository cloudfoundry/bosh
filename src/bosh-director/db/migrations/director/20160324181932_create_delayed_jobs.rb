Sequel.migration do
  up do
    create_table :delayed_jobs, force: true do
      primary_key :id
      Integer :priority, default: 0, null: false # Allows some jobs to jump to the front of the queue
      Integer :attempts, default: 0, null: false # Provides for retries, but still fail eventually.
      String :handler, :text => true, null: false # YAML-encoded string of the object that will do work
      String :last_error, :text => true           # reason for last failure (See Note below)
      Time :run_at                           # When to run. Could be Time.zone.now for immediately, or sometime in the future.
      Time :locked_at                        # Set when a client is working on this object
      Time :failed_at                        # Set when all retries have failed (actually, by default, the record is deleted instead)
      String :locked_by                          # Who is working on this object (if locked)
      String :queue                              # The name of the queue this job is in
    end

    add_index :delayed_jobs, [:priority, :run_at], name: "delayed_jobs_priority"
  end

  down do
    drop_table :delayed_jobs
  end
end
