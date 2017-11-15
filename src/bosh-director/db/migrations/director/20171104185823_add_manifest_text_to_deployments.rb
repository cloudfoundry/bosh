Sequel.migration do
  change do
    adapter_scheme =  self.adapter_scheme
    alter_table(:deployments) do
      add_column :manifest_text, [:mysql2, :mysql].include?(adapter_scheme) ? 'longtext' : 'text'
    end

    self[:deployments].all do |deployment|
      if deployment[:manifest_text].nil? || deployment[:manifest_text].empty?
        self[:deployments].where(id: deployment[:id]).update(manifest_text: deployment[:manifest] || '{}')
      end
    end
  end
end
