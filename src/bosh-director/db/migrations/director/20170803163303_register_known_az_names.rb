Sequel.migration do
  up do
    self[:instances].
      select(:availability_zone).
      exclude(availability_zone: nil).
      distinct.
      all.each do |az_entry|
      self[:local_dns_encoded_azs] << { name: az_entry[:availability_zone] }
    end

    self[:local_dns_records] << {
      instance_id: nil,
      ip: 'flush-dns',
    } if self[:local_dns_records].all.count > 0
  end
end

