Sequel.migration do
  up do
    drop_table :deployments_releases
  end

  down do
    create_table :deployments_releases do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false
      foreign_key :release_id, :releases, :null => false
      unique [:deployment_id, :release_id]
    end

    # Keeping manual track of (release_id, deployment_id) tuples
    # to avoid having to handle violated uniqueness constraint
    seen_ids = Set.new

    self[:deployments_release_versions].each do |drv|
      rv = self[:release_versions].first(:id => drv[:release_version_id])

      unless seen_ids.include?([drv[:deployment_id], rv[:release_id]])
        attrs = {
          :release_id => rv[:release_id],
          :deployment_id => drv[:deployment_id]
        }

        self[:deployments_releases].insert(attrs)
        seen_ids << [drv[:deployment_id], rv[:release_id]]
      end
    end
  end
end
