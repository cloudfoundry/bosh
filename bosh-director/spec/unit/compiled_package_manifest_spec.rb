require 'spec_helper'
require 'bosh/director/compiled_package_group'
require 'bosh/director/compiled_package_manifest'

describe Bosh::Director::CompiledPackageManifest do
  subject(:manifest) { described_class.new(group, 'fake-dir') }

  before { group.stub(compiled_packages: compiled_packages, stemcell_sha1: 'fake-stemcell-sha1') }
  let(:group) { instance_double('Bosh::Director::CompiledPackageGroup') }

  before { compiled_package.stub(package: package, blobstore_id: 'fake-compiled-package-blobstore-id') }
  let(:compiled_packages) { [compiled_package] }
  let(:compiled_package) { instance_double('Bosh::Director::Models::CompiledPackage') }

  before { package.stub(name: 'fake-package-name', fingerprint: 'fake-package-fingerprint') }
  let(:package) { instance_double('Bosh::Director::Models::Package') }

  describe '#to_h' do
    it 'generates the compiled package manifest hash' do
      expect(manifest.to_h).to eq(
        'compiled_packages' => [{
          'package_name'  => 'fake-package-name',
          'package_fingerprint' => 'fake-package-fingerprint',
          'stemcell_sha1' => 'fake-stemcell-sha1',
          'blobstore_id'  => 'fake-compiled-package-blobstore-id',
        }],
      )
    end
  end
end
