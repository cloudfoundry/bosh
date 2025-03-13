require 'spec_helper'

module Bosh::Director
  describe CompiledPackageGroup do
    include Support::StemcellHelpers

    let(:release_version) { FactoryBot.create(:models_release_version, release: release) }
    let(:release) { FactoryBot.create(:models_release) }
    let(:stemcell) { make_stemcell(sha1: 'fakestemcellsha1', operating_system: 'chrome-os') }

    let(:package1) { FactoryBot.create(:models_package, release: release, dependency_set_json: ['pkg-2', 'pkg-4'].to_json) }
    let(:package2) { FactoryBot.create(:models_package, name: 'pkg-2', version: '2', release: release) }
    let(:package3) { FactoryBot.create(:models_package, name: 'pkg-3', version: '3', release: release) }
    let(:package4) { FactoryBot.create(:models_package, name: 'pkg-4', version: '4', release: release) }
    let(:templates) { [FactoryBot.create(:models_template, package_names_json: JSON.generate([package1.name]))] }

    subject(:package_group) { CompiledPackageGroup.new(release_version, stemcell, templates) }

    describe '#compiled_packages' do
      let!(:compiled_package1) do
        FactoryBot.create(:models_compiled_package,
          package: package1,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
          dependency_key: '[["pkg-2","2"],["pkg-4","4"]]',
        )
      end
      let!(:compiled_package3) do
        FactoryBot.create(:models_compiled_package,
          package: package3,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
          dependency_key: '[]',
        )
      end
      let!(:compiled_package4) do
        FactoryBot.create(:models_compiled_package,
          package: package4,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
          dependency_key: '[]',
        )
      end

      before do
        release_version.add_package(package1)
        release_version.add_package(package2)
        release_version.add_package(package3)
        release_version.add_package(package4)
      end

      it 'returns list of packages for the given release version and stemcell' do
        expect(package_group.compiled_packages).to eq([compiled_package1, compiled_package4])
      end

      it 'only queries database once' do
        allow(Models::CompiledPackage).to receive(:[]).and_call_original
        package_group.compiled_packages
        package_group.compiled_packages
        expect(Models::CompiledPackage).to have_received(:[]).exactly(3).times
      end
    end

    describe '#stemcell_sha1' do
      it 'returns the stemcells sha1' do
        expect(package_group.stemcell_sha1).to eq('fakestemcellsha1')
      end
    end
  end
end
