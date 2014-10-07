require 'spec_helper'

module Bosh::Director::Models
  describe CompiledPackage do
    let(:package) { Package.make }
    let(:stemcell) { Stemcell.make }

    describe 'self.create_dependency_key' do
      let(:package1) { Package.new(name: 'package1', version: '123') }

      let(:package2) { Package.new(name: 'package2', version: '456') }

      it 'generates serialized JSON of the supplied package names and their fingerprint' do
        expect(CompiledPackage.create_dependency_key([])).to eq('[]')
        expect(CompiledPackage.create_dependency_key([package1])).to eq('[["package1","123"]]')
        expect(CompiledPackage.create_dependency_key([package1, package2])).to eq('[["package1","123"],["package2","456"]]')
      end
    end

    describe 'self.create_cache_key' do
      let(:package1) { Package.new(name: 'package1', fingerprint: '<package1-fingerprint>') }

      let(:package2) { Package.new(name: 'package2', fingerprint: '<package2-fingerprint>') }

      let(:package3) { Package.new(name: 'package3', fingerprint: '<package3-fingerprint>') }

      let(:stemcell) { instance_double('Bosh::Director::Models::Stemcell', sha1: '<stemcell-sha1>') }

      before do
        allow(Digest::SHA1).to receive(:hexdigest) { |input| "hexdigest for '#{input}'" }
      end

      it 'generates sha1 that uniquely identifies a package by its dependencies & stemcell' do
        expect(
          CompiledPackage.create_cache_key(package1, [], stemcell)
        ).to eq("hexdigest for '<package1-fingerprint><stemcell-sha1>'")

        expect(
          CompiledPackage.create_cache_key(package2, [package1, package3], stemcell)
        ).to eq("hexdigest for '<package2-fingerprint><stemcell-sha1><package1-fingerprint><package3-fingerprint>'")

        expect(
          CompiledPackage.create_cache_key(package3, [package1], stemcell)
        ).to eq("hexdigest for '<package3-fingerprint><stemcell-sha1><package1-fingerprint>'")
      end
    end

    describe '#generate_build_number' do
      it 'returns 1 if no compiled packages for package and stemcell' do
        expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(1)
      end

      it 'returns 2 if only one compiled package exists for package and stemcell' do
        CompiledPackage.make(package: package, stemcell: stemcell, build: 1)
        expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(2)
      end

      it 'will return 1 for new, unique combinations of packages and stemcells' do
        5.times do
          package = Package.make
          stemcell = Stemcell.make

          expect(CompiledPackage.generate_build_number(package, stemcell)).to eq(1)
        end
      end
    end

    describe '#dependency_key_sha1' do
      let(:dependency_key) { 'fake-key' }
      let(:dependency_key_sha1) { Digest::SHA1.hexdigest(dependency_key) }

      context 'when creating new compiled package' do
        it 'generates dependency key sha' do
          compiled_package = CompiledPackage.make(
            package: package,
            stemcell: stemcell,
            dependency_key: dependency_key
          )

          expect(compiled_package.dependency_key_sha1).to eq(dependency_key_sha1)
        end
      end

      context 'when updating existing compiled package' do
        it 'updates dependency key sha' do
          compiled_package = CompiledPackage.make(
            package: package,
            stemcell: stemcell,
            dependency_key: dependency_key
          )

          compiled_package.update dependency_key: 'new-fake-key'
          new_dependency_key_sha1 = Digest::SHA1.hexdigest('new-fake-key')

          expect(compiled_package.dependency_key_sha1).to eq(new_dependency_key_sha1)
        end
      end
    end
  end
end
