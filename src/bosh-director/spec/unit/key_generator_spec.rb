require 'spec_helper'

module Bosh::Director
  describe KeyGenerator do
    let(:release) { FactoryBot.create(:models_release, name: 'release-1') }
    let(:release_version) do
      FactoryBot.create(:models_release_version, release: release)
    end
    let(:key_generator) { KeyGenerator.new }

    context 'when generating from compiled packages key from the release manifest' do
      context 'when there are no compiled packages' do
        let(:compiled_packages) { [] }

        it 'raise an error' do
          expect do
            key_generator.dependency_key_from_manifest('bad-package', compiled_packages)
          end.to raise_error ReleaseExistingPackageHashMismatch, "Package 'bad-package' not found in the release manifest."
        end
      end

      context 'when compiled package has no dependencies' do
        let(:compiled_packages) do
          [
            {
              'name' => 'fake-pkg0',
              'version' => 'fake-pkg0-version',
              'fingerprint' => 'fake-pkg0-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
            {
              'name' => 'fake-pkg2',
              'version' => 'fake-pkg2-version',
              'fingerprint' => 'fake-pkg2-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
          ]
        end

        it 'should generate a dependency key' do
          key = key_generator.dependency_key_from_manifest('fake-pkg0', compiled_packages)
          expect(key).to eq('[]')
        end
      end

      context 'when compiled package has more than 1 level deep transitive dependencies' do
        let(:compiled_packages) do
          [
            {
              'name' => 'fake-pkg0',
              'version' => 'fake-pkg0-version',
              'fingerprint' => 'fake-pkg0-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => ['fake-pkg2'],
            },
            {
              'name' => 'fake-pkg1',
              'version' => 'fake-pkg1-version',
              'fingerprint' => 'fake-pkg1-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
            {
              'name' => 'fake-pkg2',
              'version' => 'fake-pkg2-version',
              'fingerprint' => 'fake-pkg2-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => ['fake-pkg3'],
            },
            {
              'name' => 'fake-pkg3',
              'version' => 'fake-pkg3-version',
              'fingerprint' => 'fake-pkg3-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
          ]
        end

        it 'should generate a dependency key' do
          key = key_generator.dependency_key_from_manifest('fake-pkg0', compiled_packages)
          expect(key).to eq('[["fake-pkg2","fake-pkg2-version",[["fake-pkg3","fake-pkg3-version"]]]]')

          key = key_generator.dependency_key_from_manifest('fake-pkg2', compiled_packages)
          expect(key).to eq('[["fake-pkg3","fake-pkg3-version"]]')
        end
      end

      context 'when compiled package has 1-level deep transitive dependencies' do
        let(:compiled_packages) do
          [
            {
              'name' => 'fake-pkg1',
              'version' => 'fake-pkg1-version',
              'fingerprint' => 'fake-pkg1-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => ['fake-pkg2', 'fake-pkg3'],
            },
            {
              'name' => 'fake-pkg2',
              'version' => 'fake-pkg2-version',
              'fingerprint' => 'fake-pkg2-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
            {
              'name' => 'fake-pkg3',
              'version' => 'fake-pkg3-version',
              'fingerprint' => 'fake-pkg3-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => [],
            },
          ]
        end

        it 'should generate a dependency key' do
          key = key_generator.dependency_key_from_manifest('fake-pkg1', compiled_packages)
          expect(key).to eq('[["fake-pkg2","fake-pkg2-version"],["fake-pkg3","fake-pkg3-version"]]')
        end
      end
    end

    context 'when generating from Models::Package' do
      context 'when package has no dependencies' do
        let(:package) do
          FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: release)
        end

        before do
          release_version.packages << package
        end

        it 'should generate a dependency key' do
          expect(key_generator.dependency_key_from_models(package, release_version)).to eq('[]')
        end
      end

      context 'when package has 1-level deep transitive dependencies' do
        context 'there is a single release version for a release' do
          let(:package) do
            FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: release, dependency_set_json: ['pkg-2', 'pkg-3'].to_json)
          end

          before do
            package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.4', release: release)
            package_3 = FactoryBot.create(:models_package, name: 'pkg-3', version: '1.7', release: release)

            [package, package_2, package_3].each { |p| release_version.packages << p }
          end

          it 'should generate a dependency key' do
            expect(key_generator.dependency_key_from_models(package, release_version)).to eq('[["pkg-2","1.4"],["pkg-3","1.7"]]')
          end
        end

        context 'there are multiple release versions for the same release' do
          let(:package) do
            FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: release, dependency_set_json: ['pkg-2', 'pkg-3'].to_json)
          end

          let(:release_version_2) do
            FactoryBot.create(:models_release_version, release: release, version: 'favourite-version')
          end

          before do
            package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.4', release: release)
            new_package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.5', release: release)
            package_3 = FactoryBot.create(:models_package, name: 'pkg-3', version: '1.7', release: release)
            new_package_3 = FactoryBot.create(:models_package, name: 'pkg-3', version: '1.8', release: release)

            [package, package_2, package_3].each { |p| release_version.packages << p }
            [package, new_package_2, new_package_3].each { |p| release_version_2.packages << p }
          end

          it 'should generate a dependency key specific to the release version' do
            expect(key_generator.dependency_key_from_models(package, release_version_2)).to eq('[["pkg-2","1.5"],["pkg-3","1.8"]]')
          end
        end

        context 'there multiple releases using the same packages' do
          let(:new_release) { FactoryBot.create(:models_release, name: 'new-release') }

          let(:package) do
            FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: new_release, dependency_set_json: ['pkg-2'].to_json)
          end

          let(:new_release_version) do
            FactoryBot.create(:models_release_version, release: new_release, version: 'favourite-version')
          end

          before do
            FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: release, dependency_set_json: ['pkg-2', 'pkg-3'].to_json)

            package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.4', release: release)
            new_package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.5', release: new_release)
            package_3 = FactoryBot.create(:models_package, name: 'pkg-3', version: '1.7', release: release)

            [package, package_2, package_3].each { |p| release_version.packages << p }
            [package, new_package_2].each { |p| new_release_version.packages << p }
          end

          it 'should generate a dependency key specific to the release version' do
            expect(key_generator.dependency_key_from_models(package, new_release_version)).to eq('[["pkg-2","1.5"]]')
          end
        end
      end

      context 'when package model has more than 1 level deep transitive dependencies' do
        context 'there is a single release version for a release' do
          let(:package) do
            FactoryBot.create(:models_package, name: 'pkg-1', version: '1.1', release: release, dependency_set_json: ['pkg-2', 'pkg-3'].to_json)
          end

          before do
            package_2 = FactoryBot.create(:models_package, name: 'pkg-2', version: '1.4', release: release, dependency_set_json: ['pkg-4'].to_json)
            package_3 = FactoryBot.create(:models_package, name: 'pkg-3', version: '1.7', release: release)
            package_4 = FactoryBot.create(:models_package, name: 'pkg-4', version: '3.7', release: release)

            [package, package_2, package_3, package_4].each { |p| release_version.packages << p }
          end

          it 'should generate a dependency key' do
            expect(key_generator.dependency_key_from_models(package, release_version)).to eq('[["pkg-2","1.4",[["pkg-4","3.7"]]],["pkg-3","1.7"]]')
          end
        end
      end
    end

    context 'when comparing dependency keys from the release manifest and Models::Package' do
      let(:package) do
        package_d = FactoryBot.create(:models_package, name: 'd', version: '1.4', release: release)
        package_b = FactoryBot.create(:models_package,
          name: 'b',
          version: '1.7',
          release: release,
          dependency_set_json: %w[d z].shuffle.to_json,
        )
        package_x = FactoryBot.create(:models_package, name: 'x', version: '1.7', release: release)
        package_z = FactoryBot.create(:models_package, name: 'z', version: '1.7', release: release)

        [package_x, package_b, package_d, package_z].shuffle.each { |p| release_version.packages << p }

        FactoryBot.create(:models_package, name: 'parent', version: '1.1', release: release, dependency_set_json: %w[b x].shuffle.to_json)
      end

      let(:compiled_packages) do
        [
          {
            'name' => 'parent',
            'version' => '1.1',
            'fingerprint' => 'fake-pkg1-fingerprint',
            'stemcell' => 'ubuntu-trusty/3000',
            'dependencies' => %w[x b].shuffle,
          },
          {
            'name' => 'd',
            'version' => '1.4',
            'fingerprint' => 'fake-pkg2-fingerprint',
            'stemcell' => 'ubuntu-trusty/3000',
            'dependencies' => [],
          },
          {
            'name' => 'b',
            'version' => '1.7',
            'fingerprint' => 'fake-pkg3-fingerprint',
            'stemcell' => 'ubuntu-trusty/3000',
            'dependencies' => %w[d z].shuffle,
          },
          {
            'name' => 'x',
            'version' => '1.7',
            'fingerprint' => 'fake-pkg3-fingerprint',
            'stemcell' => 'ubuntu-trusty/3000',
            'dependencies' => [],
          },
          {
            'name' => 'z',
            'version' => '1.7',
            'fingerprint' => 'fake-pkg3-fingerprint',
            'stemcell' => 'ubuntu-trusty/3000',
            'dependencies' => [],
          },
        ].shuffle
      end

      it 'should be equal regardless of the order of dependencies' do
        expect(key_generator.dependency_key_from_models(package, release_version)).to eq(key_generator.dependency_key_from_manifest('parent', compiled_packages))
      end
    end
  end
end
