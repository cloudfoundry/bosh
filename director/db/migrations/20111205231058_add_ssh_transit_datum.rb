Sequel.migration do
  up do
    create_table :transit_data do
      primary_key :id
      String :blobstore_id, :null => false, :unique => true
      String :tag, :null => false
      Time :timestamp, :null => false, :index => true
    end

    self[:log_bundles].each do |log_bundle|
      new_transit_datum = {
        :blobstore_id => log_bundle[:blobstore_id],
        :tag => "fetch_logs",
        :timestamp => log_bundle[:timestamp]
      }
      self[:transit_data].insert(new_transit_datum)
    end

    drop_table(:log_bundles)
  end

  down do
    create_table :log_bundles do
      primary_key :id
      String :blobstore_id, :null => false, :unique => true
      Time :timestamp, :null => false, :index => true
    end

    self[:tansit_data].each do |transit_datum|
      new_log_bundle = {
        :blobstore_id => transit_datum[:blobstore_id],
        :timestamp => transit_datum[:timestamp]
      }
      self[:log_bundles].insert(new_log_bundle)
    end

    drop_table(:transit_data)
  end
end
