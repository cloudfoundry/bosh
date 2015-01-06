require 'spec_helper'
require 'bosh/director/compiled_package_group'

module Bosh::Director
  describe CompiledPackageGroup do
    let(:release_version) { Models::ReleaseVersion.make }
    let(:stemcell) { Models::Stemcell.make(sha1: 'fake_stemcell_sha1') }

    subject(:package_group) { CompiledPackageGroup.new(release_version, stemcell) }

    describe '#compiled_packages' do
      let(:package1) { Models::Package.make }
      let(:package2) { Models::Package.make }
      let(:package3) { Models::Package.make }

      before { release_version.add_package(package1) }

      let(:transitive_dependencies1) { Set.new([package1, package2, package3]) }
      let(:transitive_dependencies2) { Set.new([]) }

      let(:dependency_key1) { 'fake_dependency_key_1' }
      let(:dependency_key2) { 'fake_dependency_key_2' }

      let!(:compiled_package1) { Models::CompiledPackage.make(package: package1, stemcell: stemcell, dependency_key: dependency_key1) }

      before do
        allow(release_version).to receive(:transitive_dependencies).with(package1).and_return(transitive_dependencies1)
        allow(Bosh::Director::Models::CompiledPackage).to receive(:create_dependency_key).with(transitive_dependencies1).and_return(dependency_key1)

        allow(release_version).to receive(:transitive_dependencies).with(package2).and_return(transitive_dependencies2)
        allow(Bosh::Director::Models::CompiledPackage).to receive(:create_dependency_key).with(transitive_dependencies2).and_return(dependency_key2)
      end

      it 'returns list of packages for the given release version and stemcell' do
        expect(package_group.compiled_packages).to eq([compiled_package1])
      end

      it 'does not return nil for packages in the release version that are not compiled' do
        release_version.add_package(package2)

        expect(package_group.compiled_packages).to eq([compiled_package1])
      end

      it 'only queries database once' do
        allow(Models::CompiledPackage).to receive(:[]).and_call_original
        package_group.compiled_packages
        package_group.compiled_packages
        expect(Models::CompiledPackage).to have_received(:[]).once
      end
    end

    describe '#stemcell_sha1' do
      it 'returns the stemcells sha1' do
        expect(package_group.stemcell_sha1).to eq('fake_stemcell_sha1')
      end
    end
  end
end
