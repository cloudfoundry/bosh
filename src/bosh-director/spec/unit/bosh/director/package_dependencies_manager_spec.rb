require 'spec_helper'

module Bosh::Director
  describe PackageDependenciesManager do
    subject(:package_dependency_manager) { PackageDependenciesManager.new(release_version) }

    let(:release) do
      FactoryBot.create(:models_release, name: 'that-release')
    end

    let(:release_version) do
      release_version = Models::ReleaseVersion.new
      release_version.release = release
      release_version.version = '1'
      release_version.packages << package1
      release_version.packages << package2
      release_version.packages << package3
      release_version
    end

    let(:package1) { Models::Package.new(name: 'package1', dependency_set: package1_dependency_set) }
    let(:package2) { Models::Package.new(name: 'package2', dependency_set: package2_dependency_set) }
    let(:package3) { Models::Package.new(name: 'package3', dependency_set: package3_dependency_set) }

    let(:package1_dependency_set) { ['package2'] }
    let(:package2_dependency_set) { ['package3'] }
    let(:package3_dependency_set) { [] }

    describe '#transitive_dependencies' do
      context 'when the dependency is linear' do
        it 'returns the packages the provided package depends on (imediately & transitively)' do
          expect(package_dependency_manager.transitive_dependencies(package1)).to eq(Set.new([package2, package3]))
          expect(package_dependency_manager.transitive_dependencies(package2)).to eq(Set.new([package3]))
          expect(package_dependency_manager.transitive_dependencies(package3)).to eq(Set.new)
        end
      end

      context 'when two packages share a dependency' do
        let(:package4) { Models::Package.new(name: 'package4', dependency_set: package4_dependency_set) }

        let(:package1_dependency_set) { %w[package2 package3] }
        let(:package2_dependency_set) { ['package4'] }
        let(:package3_dependency_set) { ['package4'] }
        let(:package4_dependency_set) { [] }

        before { release_version.packages << package4 }

        it 'returns the packages the provided package depends on (imediately & transitively)' do
          expect(package_dependency_manager.transitive_dependencies(package1)).to eq(Set.new([package2, package3, package4]))
          expect(package_dependency_manager.transitive_dependencies(package2)).to eq(Set.new([package4]))
          expect(package_dependency_manager.transitive_dependencies(package3)).to eq(Set.new([package4]))
          expect(package_dependency_manager.transitive_dependencies(package4)).to eq(Set.new)
        end
      end

      context 'when the package depends on a package not in this release' do
        it 'blows up' do
          release_version.packages.delete(package3)

          expect do
            package_dependency_manager.transitive_dependencies(package2)
          end.to raise_error "Package name 'package3' not found in release 'that-release/1'"
        end
      end
    end

    describe '#dependencies' do
      it 'returns the packages the provided package depends on' do
        expect(package_dependency_manager.dependencies(package1)).to eq(Set.new([package2]))
        expect(package_dependency_manager.dependencies(package2)).to eq(Set.new([package3]))
        expect(package_dependency_manager.dependencies(package3)).to eq(Set.new)
      end

      context 'when the package depends on a package not in this release' do
        it 'blows up' do
          release_version.packages.delete(package3)

          expect do
            package_dependency_manager.dependencies(package2)
          end.to raise_error "Package name 'package3' not found in release 'that-release/1'"
        end
      end
    end
  end
end
