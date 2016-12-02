require 'digest/sha1'

Sequel.migration do
  change do
    alter_table(:vms) do
      add_column :trusted_certs_sha1, String, { :default => Digest::SHA1.hexdigest('') }
    end
  end
end