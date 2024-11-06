require 'bosh/director/config'

Sequel.migration do
  up do
    alter_table(:vms) do
      add_column :blobstore_config_sha1, String, size: 50
      add_column :nats_config_sha1, String, size: 50
    end
    self[:vms].update(
      blobstore_config_sha1: Bosh::Director::Config.blobstore_config_fingerprint,
      nats_config_sha1: Bosh::Director::Config.nats_config_fingerprint,
    )
  end
end
