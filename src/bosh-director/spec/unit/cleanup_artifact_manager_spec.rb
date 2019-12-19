require 'spec_helper'

module Bosh::Director
  describe CleanupArtifactManager do
    context 'when dryrun is configured' do
      let(:time) { Time.now }

      before do
        Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_1', sha1: 'smurf1', type: 'exported-release').save
        Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_2', sha1: 'smurf2', type: 'exported-release').save
        stemcell1 = Models::Stemcell.make(name: 'linux', id: 2, version: 1, operating_system: 'woo', cid: 'stemcell-cid-1')
        Models::Stemcell.make(name: 'linux', id: 3, version: 2, operating_system: 'woo', cid: 'stemcell-cid-2')
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
        Models::OrphanedVm.make(deployment_name: 'dep1', orphaned_at: time, availability_zone: 'az1', instance_name: 'sad-vm', cid: 'vm-cid-1')
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
          expect(result.keys).to eq %i[releases stemcells compiled_packages orphaned_disks orphaned_vms exported_releases dns_blobs]
          expect(result[:releases]).to eq([
            { 'name' => 'release-c', 'versions' => ['1'] },
            { 'name' => 'release-d', 'versions' => ['2'] },
          ])
          expect(result[:stemcells]).to match_array([
            { 'name' => 'linux', 'operating_system' => 'woo', 'version' => '1', 'cid' => 'stemcell-cid-1', 'cpi' => '', 'deployments' => [], 'api_version' => nil, 'id' => 2 },
            { 'name' => 'linux', 'operating_system' => 'woo', 'version' => '2', 'cid' => 'stemcell-cid-2', 'cpi' => '', 'deployments' => [], 'api_version' => nil, 'id' => 3 },
          ])
          expect(result[:compiled_packages]).to eq([
            { package_name: 'package1', stemcell_os: 'woo', stemcell_version: '1' },
          ])
          expect(result[:orphaned_disks].map { |o| o['disk_cid'] }).to match_array %w[fake-cid-1 fake-cid-2]
          expect(result[:orphaned_vms].length).to eq 1
          expect(result[:orphaned_vms].first).to eq(
            'az' => 'az1',
            'cid' => 'vm-cid-1',
            'deployment_name' => 'dep1',
            'instance_name' => 'sad-vm',
            'ip_addresses' => [],
            'orphaned_at' => time.utc.to_s,
          )
          expect(result[:exported_releases]).to eq %w[exported_release_id_1 exported_release_id_2]
          expect(result[:dns_blobs]).to eq %w[dns_blob1]
        end
      end

      context 'when remove_all is false' do
        let(:remove_all) { false }

        it 'keeps more items and reports what it would delete' do
          result = subject.show_all
          expect(result).to match(
            releases: [],
            stemcells: [],
            compiled_packages: [],
            orphaned_disks: [],
            orphaned_vms: [hash_including('cid' => 'vm-cid-1')],
            exported_releases: %w[exported_release_id_1 exported_release_id_2],
            dns_blobs: [],
          )
        end
      end
    end
  end
end
