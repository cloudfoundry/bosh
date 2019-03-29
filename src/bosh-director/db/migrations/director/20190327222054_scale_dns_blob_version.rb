Sequel.migration do
  up do
    max_id = self[:local_dns_blobs].max(:id)
    max_version = self[:local_dns_blobs].max(:version)
    next if max_id.nil? || max_version.nil?

    (max_version - max_id).times do
      self[:local_dns_blobs] << {}
    end

    self[:local_dns_blobs].where { id > max_id }.delete
  end
end
