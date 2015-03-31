Sequel.migration do
  change do
    adapter_scheme =  self.adapter_scheme

    create_table :cloud_configs do
      primary_key :id

      if [:mysql2, :mysql].include?(adapter_scheme)
        longtext :properties
      else
        text :properties
      end

      Time :created_at, null: false

      index :created_at
    end
  end
end
