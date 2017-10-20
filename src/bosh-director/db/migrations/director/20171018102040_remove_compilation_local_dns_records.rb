Sequel.migration do
  up do
    self[:local_dns_records].where(
      instance_id: self[:instances]
        .where(compilation: true)
        .select(:id)
        .collect { |i| i[:id] }
    ).delete
  end
end
