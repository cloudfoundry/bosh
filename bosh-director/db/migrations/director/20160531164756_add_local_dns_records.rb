Sequel.migration do
  up do
    create_table :local_dns_records do
      primary_key :id
      Time :timestamp, :index => true, :null => false
      # @todo should name+ip be unique?
      String :name, :unique => true, :null => false
      String :ip, :unique => false, :null => false
    end
  end

  down do
    drop_table :local_dns_records
  end
end
