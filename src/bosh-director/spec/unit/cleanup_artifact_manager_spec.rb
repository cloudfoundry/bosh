require 'spec_helper'

module Bosh::Director
  describe CleanupArtifactManager do
    context 'when dryrun is configured' do
      before do
        Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_1', sha1: 'smurf1', type: 'exported-release').save
        Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_2', sha1: 'smurf2', type: 'exported-release').save
        stemcell1 = Models::Stemcell.make(name: 'linux', id: 2, version: 1, operating_system: 'woo')
        Models::Stemcell.make(name: 'linux', id: 3, version: 2, operating_system: 'woo')
        release1 = Models::Release.make(name: 'release-c')
        release2 = Models::Release.make(name: 'release-d')
        Models::ReleaseVersion.make(release: release1, version: '1')
        Models::ReleaseVersion.make(release: release2, version: '2')
        package = Models::Package.make(name: 'package1', release: release1, blobstore_id: 'package_blob_id_1')
        Models::CompiledPackage.make(
          package: package,
          stemcell_os: stemcell1.operating_system,
          stemcell_version: stemcell1.version,
          blobstore_id: 'compiled-package-1',
        )
        Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
        Models::OrphanDisk.make(disk_cid: 'fake-cid-2')
        Models::OrphanedVm.make(instance_name: 'sad-vm', cid: 'vm-cid-1')
        dns_blob = Bosh::Director::Models::Blob.new(blobstore_id: 'dns_blob1', sha1: 'smurf3', type: 'dns').save
        Models::LocalDnsBlob.make(created_at: Time.now - 100, blob: dns_blob)

        blobstore = instance_double(Bosh::Blobstore::BaseClient, delete: nil)
        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      end

      subject { CleanupArtifactManager.new(remove_all, logger) }
      context 'when remove_all is specified' do
        let(:remove_all) { true }

        it 'reports the releases and stemcells it would delete' do
          result = subject.show_all
          expect(result).to eq(
            releases: %w[release-c/["1"] release-d/["2"]],
            stemcells: %w[woo/1 woo/2],
            compiled_packages: ['package1[woo/1]'],
            orphaned_disks: %w[fake-cid-1 fake-cid-2],
            orphaned_vms: ['sad-vm/vm-cid-1'],
            exported_releases: %w[exported_release_id_1 exported_release_id_2],
            dns_blobs: ['dns_blob1'],
          )
        end
      end

      context 'when remove_all is false' do
        let(:remove_all) { false }

        it 'keeps more items and reports what it would delete' do
          result = subject.show_all
          expect(result).to eq(
            releases: [],
            stemcells: [],
            compiled_packages: [],
            orphaned_disks: [],
            orphaned_vms: ['sad-vm/vm-cid-1'],
            exported_releases: %w[exported_release_id_1 exported_release_id_2],
            dns_blobs: [],
          )
        end
      end
    end
  end
end
