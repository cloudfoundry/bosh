require 'spec_helper'

module Bosh::Director
  module CompiledRelease
    describe Manifest do
      subject(:compiled_release_manifest) { Manifest.new(manifest_hash) }
      let(:manifest_hash) do
        {
          'compiled_packages' => [
            {
              'name' => 'fake-pkg1',
              'version' => 'fake-pkg1-version',
              'fingerprint' => 'fake-pkg1-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => ['fake-pkg2', 'fake-pkg3']
            },
            {
              'name' => 'fake-pkg2',
              'version' => 'fake-pkg2-version',
              'fingerprint' => 'fake-pkg2-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => []
            },
            {
              'name' => 'fake-pkg3',
              'version' => 'fake-pkg3-version',
              'fingerprint' => 'fake-pkg3-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => []
            },
            {
              'name' => 'renamed-fake-pkg1',
              'version' => 'fake-pkg1-version',
              'fingerprint' => 'fake-pkg1-fingerprint',
              'stemcell' => 'ubuntu-trusty/3000',
              'dependencies' => ['fake-pkg2', 'fake-pkg3']
            },
          ]
        }
      end

      describe 'has_matching_package' do
        it 'returns true when it has a matching package' do
          expect(compiled_release_manifest.has_matching_package('fake-pkg1', 'ubuntu-trusty', '3000', '[["fake-pkg2","fake-pkg2-version"],["fake-pkg3","fake-pkg3-version"]]')).to be(true)
          expect(compiled_release_manifest.has_matching_package('fake-pkg2', 'ubuntu-trusty', '3000', '[]')).to be(true)
          expect(compiled_release_manifest.has_matching_package('fake-pkg3', 'ubuntu-trusty', '3000', '[]')).to be(true)
        end

        describe 'when the dependency key does not match' do
          it 'returns false' do
            expect(compiled_release_manifest.has_matching_package('fake-pkg1', 'ubuntu-trusty', '3000', '[["fake-pkg2","fake-pkg2-version"],["fake-pkg4","fake-pkg4-version"]]')).to be(false)
          end
        end

        describe 'when the the manifest does not contain the package' do
          it 'returns false' do
            expect(compiled_release_manifest.has_matching_package('fake-pkgX', 'ubuntu-trusty', '3000', '[]')).to be(false)
          end
        end

        describe 'when the the os does not contain the package' do
          it 'returns false' do
            expect(compiled_release_manifest.has_matching_package('fake-pkg2', 'centos7', '3000', '[]')).to be(false)
          end
        end

        describe 'when the the os version does not contain the package' do
          it 'returns false' do
            expect(compiled_release_manifest.has_matching_package('fake-pkg2', 'ubuntu-trusty', '2999', '[]')).to be(false)
          end
        end
      end

      describe 'fingerprints_not_matching_packages' do
        let(:packages) do
          [
            {
              name: 'fake-pkg1',
              fingerprint: 'fake-pkg1-fingerprint'
            },
            {
              name: 'fake-pkg2',
              fingerprint: 'fake-pkg2-fingerprint'
            },
            {
              name: 'fake-pkg3',
              fingerprint: 'fake-pkg3-fingerprint'
            },
          ]
        end

        it 'returns fingerprints from the manifest that do not match the name and fingerprint of provided packages' do
          expect(compiled_release_manifest.fingerprints_not_matching_packages(packages)).to eq(['fake-pkg1-fingerprint'])
        end
      end
    end
  end
end
