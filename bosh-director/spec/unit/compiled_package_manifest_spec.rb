require 'spec_helper'
require 'bosh/director/compiled_package_group'
require 'bosh/director/compiled_package_manifest'

describe Bosh::Director::CompiledPackageManifest do
  subject(:manifest) { described_class.new(group) }

  let(:release) { instance_double('Bosh::Director::Models::Release', name: 'fake-release-name') }
  let(:release_version) do
    instance_double('Bosh::Director::Models::ReleaseVersion',
                    commit_hash: 'fake-commit-hash',
                    version: 'fake-release-version',
                    release: release)
  end

  before do
    group.stub(compiled_packages: compiled_packages, stemcell_sha1: 'fake-stemcell-sha1',
               release_version: release_version)
  end
  let(:group) { instance_double('Bosh::Director::CompiledPackageGroup') }

  before { compiled_package.stub(package: package, sha1: 'fake-compiled-package-sha1',
                                 blobstore_id: 'fake-compiled-package-blobstore-id') }
  let(:compiled_packages) { [compiled_package] }
  let(:compiled_package) { instance_double('Bosh::Director::Models::CompiledPackage') }

  before { package.stub(name: 'fake-package-name', fingerprint: 'fake-package-fingerprint') }
  let(:package) { instance_double('Bosh::Director::Models::Package') }

  describe '#to_h' do
    it 'generates the compiled package manifest hash' do
      expect(manifest.to_h).to eq(
        'release_name' => 'fake-release-name',
        'release_version' => 'fake-release-version',
        'release_commit_hash' => 'fake-commit-hash',
        'compiled_packages' => [{
          'package_name'  => 'fake-package-name',
          'package_fingerprint' => 'fake-package-fingerprint',
          'compiled_package_sha1' => 'fake-compiled-package-sha1',
          'stemcell_sha1' => 'fake-stemcell-sha1',
          'blobstore_id'  => 'fake-compiled-package-blobstore-id',
        }],
      )
    end
  end
end
