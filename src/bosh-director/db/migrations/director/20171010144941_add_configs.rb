Sequel.migration do
  change do
    adapter_scheme =  self.adapter_scheme

    create_table :configs do
      primary_key :id

      String :name, :null => false
      String :type, :null => false

      if [:mysql2, :mysql].include?(adapter_scheme)
        longtext :content
      else
        text :content
      end

      Time :created_at, null: false

      TrueClass :deleted, default: false
    end
  end
end
