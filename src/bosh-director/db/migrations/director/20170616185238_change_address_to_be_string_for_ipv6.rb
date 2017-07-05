Sequel.migration do
  change do
    alter_table :ip_addresses do
      add_column(:address_temp, String, unique: true)
    end

    self[:ip_addresses].each do |ip_address|
      self[:ip_addresses].filter(:id => ip_address[:id]).update(address_temp: ip_address[:address].to_s)
    end

    alter_table :ip_addresses do
      drop_column :address
      rename_column :address_temp, :address_str
      add_index [:address_str], unique: true, address_str: 'unique_address_str'
      set_column_not_null :address_str
    end
  end
end
