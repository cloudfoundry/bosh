require 'spec_helper'
require 'bosh/director/compiled_package_group'

module Bosh::Director
  describe CompiledPackageGroup do
    include Support::StemcellHelpers

    let(:release_version) { Models::ReleaseVersion.make(release: release) }
    let(:release) { Models::Release.make }
    let(:stemcell) { make_stemcell(sha1: 'fakestemcellsha1', operating_system: 'chrome-os') }

    subject(:package_group) { CompiledPackageGroup.new(release_version, stemcell) }

    describe '#compiled_packages' do
      let(:package1) { Models::Package.make(release: release, dependency_set_json: ['pkg-2'].to_json) }
      let(:package2) { Models::Package.make(name: 'pkg-2', version: '2', release: release) }

      let!(:compiled_package1) { Models::CompiledPackage.make(package: package1, stemcell_os: stemcell.os, stemcell_version: stemcell.version, dependency_key: '[["pkg-2","2"]]') }

      before do
        release_version.add_package(package1)
        release_version.add_package(package2)
      end

      it 'returns list of packages for the given release version and stemcell' do
        expect(package_group.compiled_packages).to eq([compiled_package1])
      end

      it 'only queries database once' do
        allow(Models::CompiledPackage).to receive(:[]).and_call_original
        package_group.compiled_packages
        package_group.compiled_packages
        expect(Models::CompiledPackage).to have_received(:[]).twice
      end
    end

    describe '#stemcell_sha1' do
      it 'returns the stemcells sha1' do
        expect(package_group.stemcell_sha1).to eq('fakestemcellsha1')
      end
    end
  end
end
