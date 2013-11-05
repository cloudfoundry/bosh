require 'spec_helper'

module Bosh::Director::Models
  describe ReleaseVersion do
    describe '#package_by_name' do
      let(:package) do
        Package.new(name: 'this-releases-package')
      end

      subject(:release_version) do
        release_version = ReleaseVersion.new
        release_version.packages << package
        release_version
      end

      context 'when the package is part of the release' do
        it 'returns the package object given its name' do
          expect(release_version.package_by_name('this-releases-package')).to eq(package)
        end
      end

      context 'when the package is not part of the release' do
        it 'blows up' do
          expect {
            release_version.package_by_name('another-releases-package')
          }.to raise_error 'key not found: "another-releases-package"'
        end
      end
    end

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
        it 'blows up' do
          release_version.packages.delete(package3)

          expect {
            release_version.dependencies(package2.name)
          }.to raise_error 'key not found: "package3"'
        end
      end
    end

    describe '#package_dependency_key' do
      let(:package1) do
        Package.new(name: 'package1', version: '123')
      end

      let(:package2) do
        Package.new(name: 'package2', dependency_set: ['package1', 'package3'], version: '456')
      end

      let(:package3) do
        Package.new(name: 'package3', dependency_set: ['package1'], version: '789')
      end

      subject(:release_version) do
        release_version = ReleaseVersion.new
        release_version.packages << package1
        release_version.packages << package2
        release_version.packages << package3
        release_version
      end

      it 'generates serialized JSON of packages that the given package depends on' do
        expect(release_version.package_dependency_key(package1.name)).to eq('[]')
        expect(release_version.package_dependency_key(package2.name)).to eq('[["package1","123"],["package3","789"]]')
        expect(release_version.package_dependency_key(package3.name)).to eq('[["package1","123"]]')
      end
    end

    describe '#package_cache_key' do
      let(:package1) do
        Package.new(name: 'package1', fingerprint: '<package1-fingerprint>')
      end

      let(:package2) do
        Package.new(name: 'package2', dependency_set: ['package1', 'package3'], fingerprint: '<package2-fingerprint>')
      end

      let(:package3) do
        Package.new(name: 'package3', dependency_set: ['package1'], fingerprint: '<package3-fingerprint>')
      end

      let(:stemcell) do
        instance_double('Bosh::Director::Models::Stemcell', sha1: '<stemcell-sha1>')
      end

      subject(:release_version) do
        release_version = ReleaseVersion.new
        release_version.packages << package1
        release_version.packages << package2
        release_version.packages << package3
        release_version
      end

      before do
        Digest::SHA1.stub(:hexdigest) do |input|
          "hexdigest for '#{input}'"
        end
      end

      it 'generates sha1 sum of fingerprints of stemcell and packages that the given package depends on' do
        expect(
          release_version.package_cache_key(package1.name, stemcell)
        ).to eq("hexdigest for '<package1-fingerprint><stemcell-sha1>'")

        expect(
          release_version.package_cache_key(package2.name, stemcell)
        ).to eq("hexdigest for '<package2-fingerprint><stemcell-sha1><package1-fingerprint><package3-fingerprint>'")

        expect(
          release_version.package_cache_key(package3.name, stemcell)
        ).to eq("hexdigest for '<package3-fingerprint><stemcell-sha1><package1-fingerprint>'")
      end
    end
  end
end
