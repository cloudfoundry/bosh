Sequel.migration do
  change do
    # sqlite uses bigint for all int fields already, so skip this
    # (and if we try to do this on sqlite, it breaks the primary key sequence)
    next if adapter_scheme == :sqlite

    set_column_type :local_dns_records, :id, :Bignum
    set_column_type :local_dns_blobs, :id, :Bignum
    set_column_type :local_dns_blobs, :version, :Bignum
    set_column_type :agent_dns_versions, :id, :Bignum
    set_column_type :agent_dns_versions, :dns_version, :Bignum
  end
end
