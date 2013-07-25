require 'spec_helper'

describe Bosh::Director::Blobstores do
  let(:config) { BD::Config.load_file(asset("test-director-config.yml")) }
  let(:blobstores) { described_class.new(config) }

  context "normal blobstore" do
    it "provides the blobstore client" do
      expect(blobstores.blobstore).to be_a(Bosh::Blobstore::SimpleBlobstoreClient)
    end
  end

  context "backup destination blobstore" do
    it "provides the blobstore client" do
      expect(blobstores.backup_destination).to be_a(Bosh::Blobstore::S3BlobstoreClient)
    end

    context 'when no backup blobstore is specified' do
      let(:config_hash) do
        {
            'blobstore' => {
                'provider' => 's3',
                'options' => {
                    'bucket_name' => 'foo',
                    'access_key_id' => 'asdf',
                    'secret_access_key' => 'zxcv'
                }
            }
        }
      end
      let(:config) { BD::Config.load_hash(config_hash) }

      it 'raises an exception' do
        expect {
          blobstores.backup_destination
        }.to raise_error('No backup destination configured')
      end
    end
  end
end