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
      let(:job) { Models::Template.make(release: release, package_names_json: package_names.to_json) }
      let(:job2) { Models::Template.make(release: release, package_names_json: package_names.to_json) }
      let(:package_names) { [package1.name, package2.name] }
      let(:package1) { Models::Package.make(release: release, dependency_set_json: ['pkg-2'].to_json) }
      let(:package2) { Models::Package.make(name: 'pkg-2', version: '2', release: release) }

      let!(:compiled_package1) { Models::CompiledPackage.make(package: package1, stemcell_os: stemcell.os, stemcell_version: stemcell.version, dependency_key: '[["pkg-2","2"]]') }
      let!(:compiled_package2) { Models::CompiledPackage.make(package: package2, stemcell_os: stemcell.os, stemcell_version: stemcell.version) }

      before do
        release_version.add_template(job)
        release_version.add_template(job2)
        release_version.add_package(package1)
        release_version.add_package(package2)
      end

      it 'returns list of packages for the jobs in the given release version and stemcell' do
        expect(package_group.compiled_packages).to eq([compiled_package1, compiled_package2])
      end

      it 'only queries database once' do
        allow(Models::CompiledPackage).to receive(:[]).and_call_original
        package_group.compiled_packages
        package_group.compiled_packages
        expect(Models::CompiledPackage).to have_received(:[]).exactly(4).times
      end

      context 'when jobs include packages with transitive dependencies' do
        let(:package_names) { [package1.name] }

        it 'does not include second and higher order dependencies' do
          expect(package_group.compiled_packages).to eq([compiled_package1])
        end
      end
    end

    describe '#stemcell_sha1' do
      it 'returns the stemcells sha1' do
        expect(package_group.stemcell_sha1).to eq('fakestemcellsha1')
      end
    end
  end
end
