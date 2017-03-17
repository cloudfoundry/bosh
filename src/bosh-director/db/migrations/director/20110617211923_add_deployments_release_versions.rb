Sequel.migration do
  up do
    create_table(:deployments_release_versions) do
      primary_key :id
      foreign_key :release_version_id, :release_versions, :null => false
      foreign_key :deployment_id, :deployments, :null => false
      unique [:release_version_id, :deployment_id]
    end

    self[:deployments].each do |deployment|
      manifest = YAML.load(deployment[:manifest])

      unless manifest.is_a?(Hash) && manifest["release"] && manifest["release"]["version"]
        raise "Invalid manifest for '#{deployment[:name]}', no version data"
      end

      release_version = self[:release_versions].filter(:release_id => deployment[:release_id], :version => manifest["release"]["version"].to_s).first

      if release_version.nil?
        raise "Release version #{manifest["release"]["version"]} referenced by '#{deployment[:name]}' manifest not found"
      end

      self[:deployments_release_versions].insert(:release_version_id => release_version[:id], :deployment_id => deployment[:id])
    end
  end

  down do
    drop_table(:deployments_release_versions)
  end
end
