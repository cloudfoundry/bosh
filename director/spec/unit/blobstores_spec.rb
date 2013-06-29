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
  end
end