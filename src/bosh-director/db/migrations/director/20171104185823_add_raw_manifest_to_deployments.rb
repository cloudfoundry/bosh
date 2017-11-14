Sequel.migration do
  change do
    adapter_scheme =  self.adapter_scheme
    alter_table(:deployments) do
      add_column :raw_manifest, [:mysql2, :mysql].include?(adapter_scheme) ? 'longtext' : 'text'
    end

    self[:deployments].all do |deployment|
      if deployment[:raw_manifest].nil? || deployment[:raw_manifest].empty?
        self[:deployments].where(id: deployment[:id]).update(raw_manifest: deployment[:manifest] || '{}')
      end
    end
  end
end
