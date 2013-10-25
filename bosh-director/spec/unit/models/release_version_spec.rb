require 'spec_helper'

module Bosh::Director::Models
  describe ReleaseVersion do
    describe '#dependencies' do
      let(:package1) do
        Package.new(name: 'package1')
      end

      let(:package2) do
        Package.new(name: 'package2', dependency_set: ['package1', 'package3'])
      end

      let(:package3) do
        Package.new(name: 'package3', dependency_set: ['package1'])
      end

      subject(:release_version) do
        release_version = ReleaseVersion.new
        release_version.packages << package1
        release_version.packages << package2
        release_version.packages << package3
        release_version
      end

      it 'returns the packages the provided package depends on' do
        expect(release_version.dependencies(package1.name)).to eq([])
        expect(release_version.dependencies(package2.name)).to eq([package1, package3])
        expect(release_version.dependencies(package3.name)).to eq([package1])
      end

      context 'when the package depends on a package not in this release' do
        it 'blows up?' do
          release_version.packages.delete(package3)

          expect {
            release_version.dependencies(package2.name)
          }.to raise_error 'key not found: "package3"'
        end
      end
    end
  end
end
