Sequel.migration do
  up do
    self[:instances].select(:availability_zone).distinct.all.each do |az_entry|
      self[:local_dns_encoded_azs] << { name: az_entry[:availability_zone] }
    end

    self[:local_dns_records] << { instance_id: nil, ip: 'tombstone' }
  end
end

