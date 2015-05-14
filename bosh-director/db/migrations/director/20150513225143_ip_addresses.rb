Sequel.migration do
  change do
    create_table :ip_addresses do
      primary_key :id
      String      :network_name
      Integer     :address
      TrueClass   :allocated, default: false
      String      :type # 'static', 'dynamic', 'reserved'

      unique [:address, :network_name]
    end
  end
end
