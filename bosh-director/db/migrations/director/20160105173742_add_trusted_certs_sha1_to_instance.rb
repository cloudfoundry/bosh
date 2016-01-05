Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :trusted_certs_sha1, String, { :default => Digest::SHA1.hexdigest('') }
    end
    self[:instances].each do |row|
      if row.vm
        trusted_certs_sha1 = row.trusted_certs_sha1
        row.update(trusted_certs_sha1: trusted_certs_sha1)
      end
    end
  end
end
