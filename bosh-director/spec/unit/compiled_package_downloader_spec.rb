require 'spec_helper'
require 'bosh/director/compiled_package_downloader'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe CompiledPackageDownloader do
    include FakeFS::SpecHelpers

    let(:package1) { double('package1', name: 'pkg-001', fingerprint: 'fingerprint_for_package_1') }
    let(:package2) { double('package2', name: 'pkg-002', fingerprint: 'fingerprint_for_package_2') }

    let(:compiled_package1) { double('compiled_package1', blobstore_id: 'blobstore_id1', package: package1) }
    let(:compiled_package2) { double('compiled_package2', blobstore_id: 'blobstore_id2', package: package2) }

    let(:compiled_package_group) { double('package group', compiled_packages: [compiled_package1, compiled_package2],
                                                           stemcell_sha: 'sha_1_for_stemcell') }
    let(:blobstore_client) { double('blobstore client') }

    subject(:downloader) { CompiledPackageDownloader.new(compiled_package_group, blobstore_client) }

    describe '#download_path' do
      it 'returns path to directory with download manifest yaml and blobs for compiled packages' do
        ['blobstore_id1', 'blobstore_id2'].each do |blobstore_id|
          blobstore_client.stub(:get).with(blobstore_id, anything) do |id, file|
            file.should_receive(:close)
          end
        end


        download_dir = downloader.download

        File.should exist(File.join(download_dir, 'compiled_packages.yml'))
        File.should exist(File.join(download_dir, 'blobs', 'blobstore_id1'))
        File.should exist(File.join(download_dir, 'blobs', 'blobstore_id2'))

        File.open(File.join(download_dir, 'compiled_packages.yml')).read.should eq(<<YAML)
---
compiled_packages:
- name: pkg-001
  fingerprint: fingerprint_for_package_1
  stemcell_sha: sha_1_for_stemcell
  blobstore_id: blobstore_id1
- name: pkg-002
  fingerprint: fingerprint_for_package_2
  stemcell_sha: sha_1_for_stemcell
  blobstore_id: blobstore_id2
YAML
      end
    end
  end
end
