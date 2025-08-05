Sequel.migration do
  up do
    alter_table(:ip_addresses) do
      add_column :nic_group, Integer, null: true
    end

    from(:ip_addresses).each do |row|
      integer_representation = row[:address_str].to_i

      cidr_notation = Bosh::Director::IpAddrOrCidr.new(integer_representation).to_s

      from(:ip_addresses).where(id: row[:id]).update(address_str: cidr_notation)
    end
  end
  down do
    alter_table(:ip_addresses) do
      drop_column :nic_group
    end
    from(:ip_addresses).each do |row|
      cidr_notation = row[:address_str]

      ip_addr = Bosh::Director::IpAddrOrCidr.new(cidr_notation)
      integer_representation = ip_addr.to_i
      from(:ip_addresses).where(id: row[:id]).update(address_str: integer_representation)
    end
  end
end
