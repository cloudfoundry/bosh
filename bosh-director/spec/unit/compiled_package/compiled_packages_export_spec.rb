require 'spec_helper'
require 'bosh/director/compiled_package/compiled_packages_export'

module Bosh::Director::CompiledPackage
  describe CompiledPackagesExport do
    let(:exported_tar) { asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz') }

    describe '#extract' do

      it 'extracts the tar to a temporary directory' do
        exec = instance_double('Bosh::Exec')
        export = described_class.new(file: exported_tar, exec: exec)

        YAML.stub(:load_file).with('/fake/temp/dir/compiled_packages.MF').and_return('compiled_packages' => [])

        expect(exec).to receive(:sh).with("tar -C /fake/temp/dir -xf #{exported_tar}")
        export.extract('/fake/temp/dir') {}
      end

      it 'yields the manifest' do
        export = described_class.new(file: exported_tar)

        export.extract do |manifest|
          expect(manifest).to eq({
                                   'release_commit_hash' => '33c3eae1',
                                   'release_name' => 'bosh-release',
                                   'release_version' => '0.1-dev',
                                   'compiled_packages' => [
                                     {'package_name' => 'bar',
                                      'package_fingerprint' => 'c7e127a7973ef3b66853ac08466e74e41af27e92',
                                      'compiled_package_sha1' => '9719eeb54f69ede44cb6cd9ab147b1d3413d17ad',
                                      'stemcell_sha1' => 'shawone',
                                      'blobstore_id' => 'f4bc85ec-2e8d-4c51-818b-e5d373be7908'},
                                     {'package_name' => 'foo',
                                      'package_fingerprint' => 'b2e71f2e1c24d78be559efd08cc5bec36ce68a55',
                                      'compiled_package_sha1' => '0947bfd52c7c0494901519b7cab28d4106184134',
                                      'stemcell_sha1' => 'shawone',
                                      'blobstore_id' => '35ea0411-74df-451d-9f29-76e3283002ba'}
                                   ]})
        end
      end

      it 'yields the packages' do
        tempdir = Dir.mktmpdir

        export = described_class.new(file: exported_tar)

        export.extract(tempdir) do |_, packages|
          package1 = packages[0]
          expect(package1.package_name).to eq 'bar'
          expect(package1.package_fingerprint).to eq 'c7e127a7973ef3b66853ac08466e74e41af27e92'
          expect(package1.sha1).to eq '9719eeb54f69ede44cb6cd9ab147b1d3413d17ad'
          expect(package1.stemcell_sha1).to eq 'shawone'
          expect(package1.blobstore_id).to eq 'f4bc85ec-2e8d-4c51-818b-e5d373be7908'
          expect(package1.blob_path).to eq File.join(tempdir, 'compiled_packages', 'blobs', package1.blobstore_id)

          package2 = packages[1]
          expect(package2.package_name).to eq 'foo'
          expect(package2.package_fingerprint).to eq 'b2e71f2e1c24d78be559efd08cc5bec36ce68a55'
          expect(package2.sha1).to eq '0947bfd52c7c0494901519b7cab28d4106184134'
          expect(package2.stemcell_sha1).to eq 'shawone'
          expect(package2.blobstore_id).to eq '35ea0411-74df-451d-9f29-76e3283002ba'
          expect(package2.blob_path).to eq File.join(tempdir, 'compiled_packages', 'blobs', package2.blobstore_id)

        end
      end

      it 'cleans up' do
        tempdir = Dir.mktmpdir

        export = described_class.new(file: exported_tar)

        export.extract(tempdir) { expect(Dir.exist?(tempdir)).to be(true) }

        expect(Dir.exist?(tempdir)).to be(false)
      end

    end

  end
end
