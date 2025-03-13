require 'spec_helper'

module Bosh::Director
  describe BlobUtil do
    let(:package_name) { 'package_name' }
    let(:package_fingerprint) { 'fingerprint' }
    let(:blob_id) { 'blob_id' }
    let(:stemcell) { instance_double('Bosh::Director::DeploymentPlan::Stemcell', os: 'chrome-os', version: 'latest') }
    let(:package) { instance_double('Bosh::Director::Models::Package', name: package_name, fingerprint: package_fingerprint) }
    let(:compiled_package) { instance_double('Bosh::Director::Models::CompiledPackage', package: package, stemcell_os: stemcell.os, stemcell_version: stemcell.version, blobstore_id: blob_id) }
    let(:dep_pkg2) { instance_double('Bosh::Director::Models::Package', fingerprint: 'dp_fingerprint2', version: '9.2-dev') }
    let(:dep_pkg1) { instance_double('Bosh::Director::Models::Package', fingerprint: 'dp_fingerprint1', version: '10.1-dev') }
    let(:cache_key) { 'cache_sha1' }
    let(:dep_key) { '[]' }
    let(:blobstore) { instance_double('Bosh::Director::Blobstore::BaseClient') }


    describe '#delete_blob' do
      let(:fake_local_blobstore) { instance_double('Bosh::Director::Blobstore::S3cliBlobstoreClient') }
      before do
        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(fake_local_blobstore)
      end

      it 'deletes blob' do
        expect(fake_local_blobstore).to receive(:delete).with('fake-blobstore-id')
        expect { BlobUtil.delete_blob('fake-blobstore-id') }.to_not raise_error
      end
    end
  end
end
