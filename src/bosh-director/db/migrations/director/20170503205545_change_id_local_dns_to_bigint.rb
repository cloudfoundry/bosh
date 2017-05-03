Sequel.migration do
  change do
    set_column_type :local_dns_records, :id, Bignum
    set_column_type :local_dns_blobs, :id, Bignum
    set_column_type :local_dns_blobs, :version, Bignum
    set_column_type :agent_dns_versions, :id, Bignum
    set_column_type :agent_dns_versions, :dns_version, Bignum
  end
end
