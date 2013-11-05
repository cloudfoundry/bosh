require 'spec_helper'
require 'bosh/director/compiled_package/compiled_package'

module Bosh::Director::CompiledPackage
  describe CompiledPackage do

    subject(:compiled_package) do
      described_class.new(
        package_name: 'test-package1',
        package_fingerprint: 'test-package-fingerprint',
        sha1: 'test-compiled-package-sha1',
        stemcell_sha1: 'test-stemcell-sha1',
        blobstore_id: 'test-blobstore-id',
        blob_path: '/tmp/blob'
      )
    end

    its(:package_name) { should eq 'test-package1' }
    its(:package_fingerprint) { should eq 'test-package-fingerprint' }
    its(:sha1) { should eq 'test-compiled-package-sha1' }
    its(:stemcell_sha1) { should eq 'test-stemcell-sha1' }
    its(:blobstore_id) { should eq 'test-blobstore-id' }
    its(:blob_path) { should eq '/tmp/blob' }
  end

end
