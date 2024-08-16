require 'spec_helper'

module Bosh::Director
  describe Jobs::CleanupArtifacts do
    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    let(:update_job) do
      instance_double(
        Bosh::Director::Jobs::UpdateDeployment,
        username: 'user',
        task_id: task.id,
        event_manager: event_manager,
      )
    end

    before { allow(Config).to receive(:current_job).and_return(update_job) }

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }
      let(:config) do
        { 'remove_all' => remove_all }
      end

      describe 'when user specifies --all at the command line' do
        let(:remove_all) { true }
        it "enqueues a CleanupArtifacts job with 'clean up all' in the description" do
          expect(job_queue).to receive(:enqueue).with('fake-username', Jobs::CleanupArtifacts, 'clean up all', [config])
          Jobs::CleanupArtifacts.enqueue('fake-username', config, job_queue)
        end
      end

      describe 'when user omits --all at the command line' do
        let(:remove_all) { false }
        it "enqueues a CleanupArtifacts job with 'clean up all' in the description" do
          expect(job_queue).to receive(:enqueue).with('fake-username', Jobs::CleanupArtifacts, 'clean up', [config])
          Jobs::CleanupArtifacts.enqueue('fake-username', config, job_queue)
        end
      end
    end

    describe '#perform' do
      let(:stage) { instance_double(Bosh::Director::EventLog::Stage) }
      let(:event_log) { EventLog::Log.new }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient, delete: nil) }
      let(:release1) { FactoryBot.create(:models_release, name: 'release-1') }
      let(:release2) { FactoryBot.create(:models_release, name: 'release-2') }
      let(:thread_pool) { ThreadPool.new }
      let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
      let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
      let(:orphaned_vm_deleter) { instance_double(Bosh::Director::OrphanedVMDeleter) }
      subject(:cleanup_artifacts) { Jobs::CleanupArtifacts.new(config) }

      def make_stemcell(name:, version:, operating_system: '', id: 1)
        FactoryBot.create(:models_stemcell_upload, name: name, version: version)
        FactoryBot.create(:models_stemcell, name: name, version: version, operating_system: operating_system, id: id)
      end

      before do
        fake_locks

        stemcell1 = make_stemcell(name: 'stemcell-a', operating_system: 'gentoo_linux', version: '1', id: 1)
        make_stemcell(name: 'stemcell-b', version: '2', id: 2)

        release_version1 = FactoryBot.create(:models_release_version, version: 1, release: release1)
        FactoryBot.create(:models_release_version, version: 2, release: release2)

        package = FactoryBot.create(:models_package, release: release1, blobstore_id: 'package_blob_id_1')
        package.add_release_version(release_version1)
        FactoryBot.create(:models_compiled_package,
          package: package,
          stemcell_os: stemcell1.operating_system,
          stemcell_version: stemcell1.version,
          blobstore_id: 'compiled-package-1',
        )

        allow(Config).to receive(:event_log).and_return(event_log)
        allow(event_log).to receive(:begin_stage).and_return(stage)
        allow(stage).to receive(:advance_and_track).and_yield

        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)

        allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud_factory).to receive(:get).with('').and_return(cloud)
        allow(cloud).to receive(:delete_stemcell)
        allow(cloud).to receive(:delete_disk)

        allow(Bosh::Director::OrphanedVMDeleter).to receive(:new).and_return(orphaned_vm_deleter)

        Timecop.freeze(Time.now)
      end

      context 'when cleaning up ALL artifacts (orphaned vms, stemcells, releases AND orphaned disks)' do
        let(:config) do
          { 'remove_all' => true }
        end

        context 'when there are exported releases' do
          before do
            Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_1', sha1: 'smurf1', type: 'exported-release').save
            Bosh::Director::Models::Blob.new(blobstore_id: 'exported_release_id_2', sha1: 'smurf2', type: 'exported-release').save
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes them from blobstore and database' do
            expect(event_log).to receive(:begin_stage).with('Deleting exported releases', 2).and_return(stage)

            result = subject.perform
            expect(blobstore).to have_received(:delete).with('exported_release_id_1')
            expect(blobstore).to have_received(:delete).with('exported_release_id_2')
            expect(result).to eq(
              'Deleted 2 release(s), 2 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "2 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
            )
            expect(Models::Blob.all).to be_empty
          end
        end

        context 'when there are orphaned disks' do
          before do
            FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-1')
            FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-2')
            allow(blobstore).to receive(:delete).with('package_blob_id_1')
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'logs and returns the result' do
            expect(event_log).to receive(:begin_stage).with('Deleting packages', 1).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting jobs', 0).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 2).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting orphaned disks', 2).and_return(stage)

            result = subject.perform
            expect(result).to eq(
              'Deleted 2 release(s), 2 stemcell(s), 0 extra compiled package(s), 2 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
            )

            expect(Models::OrphanDisk.all).to be_empty
            expect(Models::Release.all).to be_empty
            expect(Models::Stemcell.all).to be_empty
          end
        end

        context 'when there are orphaned vms' do
          let(:orphaned_vm_1) { FactoryBot.create(:models_orphaned_vm, cid: 'fake-cid-1') }
          let(:orphaned_vm_2) { FactoryBot.create(:models_orphaned_vm, cid: 'fake-cid-2') }
          before do
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'logs and returns the result' do
            expect(event_log).to receive(:begin_stage).with('Deleting packages', 1).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting jobs', 0).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 2).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting orphaned disks', 0).and_return(stage)
            expect(event_log).to receive(:begin_stage).with('Deleting orphaned vms', 2).and_return(stage)

            expect(orphaned_vm_deleter).to receive(:delete_vm).with(orphaned_vm_1, 10)
            expect(orphaned_vm_deleter).to receive(:delete_vm).with(orphaned_vm_2, 10)

            result = subject.perform
            expect(result).to eq(
              'Deleted 2 release(s), 2 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 2 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
            )

            expect(Models::OrphanDisk.all).to be_empty
            expect(Models::Release.all).to be_empty
            expect(Models::Stemcell.all).to be_empty
          end
        end

        context 'when there are compiled packages for stemcells that are no longer available' do
          let(:releases_deleter) { instance_double(Jobs::Helpers::NameVersionReleaseDeleter, find_and_delete_release: nil) }
          let(:compiled_package_deleter) { instance_double(Jobs::Helpers::CompiledPackageDeleter, delete: nil) }
          let(:orphaned_compiled_package) do
            package = FactoryBot.create(:models_package, release: release1, blobstore_id: 'package_blob_id_1')
            FactoryBot.create(:models_compiled_package,
              package: package,
              stemcell_os: 'windows',
              stemcell_version: '3.1',
              blobstore_id: 'orphaned-compiled-package-1',
            )
          end

          before do
            orphaned_compiled_package
            allow(Jobs::Helpers::NameVersionReleaseDeleter).to receive(:new).and_return(releases_deleter)
            allow(Jobs::Helpers::CompiledPackageDeleter).to receive(:new).and_return(compiled_package_deleter)
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes those compiled packages' do
            result = subject.perform
            expect(compiled_package_deleter).to have_received(:delete).with(orphaned_compiled_package)
            expect(result).to eq(
              'Deleted 2 release(s), 2 stemcell(s), 2 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
            )
          end
        end

        context 'when there are more than 2 stemcells and/or releases' do
          context 'and there are no orphaned disks' do
            it 'removes all stemcells and releases' do
              make_stemcell(name: 'stemcell-a', version: '10', id: 3)
              make_stemcell(name: 'stemcell-b', version: '10', id: 4)

              FactoryBot.create(:models_release_version, version: 10, release: release1)
              FactoryBot.create(:models_release_version, version: 10, release: release2)

              expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 4)
              expect(event_log).to receive(:begin_stage).with('Deleting releases', 4)

              allow(blobstore).to receive(:delete).with('package_blob_id_1')
              result = subject.perform

              expect(result).to eq(
                'Deleted 4 release(s), 4 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
                "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
              )

              expect(Models::Stemcell.all).to be_empty
              expect(Models::StemcellUpload.all).to be_empty
              expect(Models::Release.all).to be_empty
            end
          end
        end

        context 'when deleting multiple versions of the same release' do
          it 'removes them in sequence' do
            FactoryBot.create(:models_release_version, version: 10, release: release1)
            FactoryBot.create(:models_release_version, version: 9, release: release1)

            locks_acquired = []
            allow(Bosh::Director::Lock).to receive(:new) do |name, *_args|
              locks_acquired << name
              Support::FakeLocks::FakeLock.new
            end

            expect(event_log).to receive(:begin_stage).with('Deleting releases', 4)

            allow(blobstore).to receive(:delete).with('package_blob_id_1')
            result = subject.perform

            expect(locks_acquired).to eq(locks_acquired.uniq)
            expect(result).to eq(
              'Deleted 4 release(s), 2 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now}",
            )
          end
        end

        context 'when there is at least one deployment' do
          let!(:blob1) { Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now - 4000) }
          let!(:most_recent_blob) { Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now - 1) }

          before do
            FactoryBot.create(:models_deployment)
            allow(blobstore).to receive(:delete).with(blob1.blob.blobstore_id)
          end

          it 'removes all but the most recent dns blob' do
            subject.perform

            expect(Models::LocalDnsBlob.all).to contain_exactly(most_recent_blob)
            expect(Models::Blob.all).to contain_exactly(most_recent_blob.blob)
          end
        end

        context 'when there are no deployments' do
          before do
            blob1 = Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now - 4000)
            blob2 = Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now - 1)

            allow(blobstore).to receive(:delete).with(blob1.blob.blobstore_id)
            allow(blobstore).to receive(:delete).with(blob2.blob.blobstore_id)
          end

          it 'removes all dns blobs' do
            subject.perform

            expect(Models::LocalDnsBlob.all).to be_empty
            expect(Models::Blob.all).to be_empty
          end
        end
      end

      context 'when cleaning up only orphaned vms, stemcells, releases, and exported releases' do
        let(:config) do
          {}
        end
        it 'logs and returns the result' do
          expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
          expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

          expect(thread_pool).not_to receive(:process)
          result = subject.perform

          expect(result).to eq(
            'Deleted 0 release(s), 0 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
            "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now - 3600}",
          )
          expect(Models::Release.all.count).to eq(2)
          expect(Models::Stemcell.all.count).to eq(2)
        end

        context 'when there are more than 2 stemcells and/or releases' do
          it 'keeps the 2 latest versions of each stemcell' do
            expect(blobstore).not_to receive(:delete).with('compiled-package-1')

            make_stemcell(name: 'stemcell-a', version: '10', id: 3)
            make_stemcell(name: 'stemcell-a', version: '9', id: 4)
            make_stemcell(name: 'stemcell-b', version: '10', id: 5)
            make_stemcell(name: 'stemcell-b', version: '9', id: 6)

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

            expect(thread_pool).to receive(:process).exactly(2).times.and_yield
            result = subject.perform

            expect(result).to eq(
              'Deleted 0 release(s), 2 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now - 3600}",
            )

            expect(Models::StemcellUpload.all.count).to eq(4)
            expect(Models::Stemcell.all.count).to eq(4)
            expect(Models::Release.all.count).to eq(2)
          end

          it 'keeps the last 2 most recently used releases' do
            expect(blobstore).to receive(:delete).with('compiled-package-1')

            FactoryBot.create(:models_release_version, version: 10, release: release1)
            FactoryBot.create(:models_release_version, version: 10, release: release2)
            FactoryBot.create(:models_release_version, version: 9, release: release1)
            FactoryBot.create(:models_release_version, version: 9, release: release2)

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 2)

            expect(thread_pool).to receive(:process).exactly(2).times.and_yield
            result = subject.perform

            expect(result).to eq(
              'Deleted 2 release(s), 0 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now - 3600}",
            )

            expect(Models::Release.all.count).to eq(2)
            expect(Models::Stemcell.all.count).to eq(2)
          end
        end

        context 'when there are stemcells and releases in use' do
          before do
            deployment1 = FactoryBot.create(:models_deployment, name: 'first')
            deployment2 = FactoryBot.create(:models_deployment, name: 'second')

            stemcell_with_deployment1 = FactoryBot.create(:models_stemcell, name: 'stemcell-c', id: 3)
            stemcell_with_deployment1.add_deployment(deployment1)

            stemcell_with_deployment2 = FactoryBot.create(:models_stemcell, name: 'stemcell-d', id: 4)
            stemcell_with_deployment2.add_deployment(deployment2)

            release1 = FactoryBot.create(:models_release, name: 'release-c')
            release2 = FactoryBot.create(:models_release, name: 'release-d')
            version1 = FactoryBot.create(:models_release_version, version: 1, release: release1)
            version2 = FactoryBot.create(:models_release_version, version: 2, release: release2)

            version1.add_deployment(deployment1)
            version2.add_deployment(deployment2)
          end

          it 'does not delete any stemcells and releases currently in use' do
            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

            expect(thread_pool).not_to receive(:process)
            result = subject.perform

            expect(result).to eq(
              'Deleted 0 release(s), 0 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 0 dns blob(s) created before #{Time.now - 3600}",
            )

            expect(Models::Release.all.count).to eq(4)
            expect(Models::Stemcell.all.count).to eq(4)
          end
        end

        context 'when there are exported releases' do
          before do
            Bosh::Director::Models::Blob.new(type: 'exported-release', blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save
            Bosh::Director::Models::Blob.new(type: 'exported-release', blobstore_id: 'ephemeral_blob_id_2', sha1: 'smurf2').save
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_1')
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_2')
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes them from blobstore and database' do
            expect(event_log).to receive(:begin_stage).with('Deleting exported releases', 2).and_return(stage)

            result = subject.perform

            expect(result).to eq(
              'Deleted 0 release(s), 0 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "2 exported release(s), Deleted 0 dns blob(s) created before #{Time.now - 3600}",
            )
            expect(Models::Blob.all).to be_empty
          end
        end

        context 'when there are dns blobs' do
          let!(:old_dns_blob) { Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now - 4000) }
          let!(:recent_dns_blobs) do
            recent_blobs = []
            10.times { recent_blobs << Bosh::Director::Models::LocalDnsBlob.make(created_at: Time.now) }
            recent_blobs
          end

          before do
            expect(blobstore).to receive(:delete).with(old_dns_blob.blob.blobstore_id)
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes them from blobstore and database' do
            expect(event_log).to receive(:begin_stage).with('Deleting dns blobs', 1).and_return(stage)

            result = subject.perform

            expect(result).to eq(
              'Deleted 0 release(s), 0 stemcell(s), 0 extra compiled package(s), 0 orphaned disk(s), 0 orphaned vm(s), ' \
              "0 exported release(s), Deleted 1 dns blob(s) created before #{Time.now - 3600}",
            )
            expect(Models::LocalDnsBlob.all).to match_array(recent_dns_blobs)
            expect(Models::Blob.all).to match_array(recent_dns_blobs.map(&:blob))
          end
        end
      end

      context 'when director was unable to delete a disk' do
        let(:config) do
          { 'remove_all' => true }
        end

        before do
          FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-1')
          FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-2')
          expect(blobstore).to receive(:delete).with('compiled-package-1')
        end

        it 're-raises the error' do
          expect(cloud).to receive(:delete_disk).and_raise(Exception.new('Bad stuff happened!'))

          expect do
            subject.perform
          end.to raise_error Exception, 'Bad stuff happened!'
        end
      end

      context 'when find_and_delete_release raises' do
        let(:config) do
          { 'remove_all' => true }
        end

        before do
          allow(blobstore).to receive(:delete).and_raise('nope')
          FactoryBot.create(:models_orphan_disk, disk_cid: 'fake-cid-1')
          Models::Blob.new(type: 'exported-release', blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save
        end

        it 'does not delete stemcells, orphan disks and exported releases' do
          expect { subject.perform }.to raise_error('nope')
          expect(Models::Stemcell.all).to_not be_empty
          expect(Models::OrphanDisk.all).to_not be_empty
          expect(Models::Blob.all).to_not be_empty
        end
      end
    end
  end
end
