Sequel.migration do
  change do
    index = indexes(:local_dns_blobs).detect { |name, _| name.to_s == 'blobstore_id_idx' }
    if !index.nil?
      alter_table(:local_dns_blobs) do
        drop_index(nil, name: 'blobstore_id_idx')
      end
    end
  end
end
