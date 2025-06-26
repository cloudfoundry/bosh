Sequel.migration do
  up do
    # Iterate over each record to convert integer IP to CIDR notation
    from(:ip_addresses).each do |row|
      integer_representation = row[:address_str].to_i

      # Convert the integer to IPAddr object
      cidr_notation = Bosh::Director::IpAddrOrCidr.new(integer_representation).to_cidr_s

      # Update the row with the new CIDR notation
      from(:ip_addresses).where(id: row[:id]).update(address_str: cidr_notation)
    end
  end
  down do
    # Revert CIDR notation back to integer representation
    from(:ip_addresses).each do |row|
      cidr_notation = row[:address_str]

      ip_addr = Bosh::Director::IpAddrOrCidr.new(cidr_notation)

      # Convert IPAddr object back to integer
      integer_representation = ip_addr.to_i

      # Update the column to store integer representation
      from(:ip_addresses).where(id: row[:id]).update(address_str: integer_representation)
    end
  end
end
