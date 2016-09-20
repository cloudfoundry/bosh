require 'spec_helper'

module Bosh::Director
  describe Jobs::CleanupArtifacts do
    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }
      let(:config) { {'remove_all' => remove_all} }

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
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      let(:release_1) { Models::Release.make(name: 'release-1') }
      let(:release_2) { Models::Release.make(name: 'release-2') }
      let(:thread_pool) { ThreadPool.new }
      subject(:cleanup_artifacts) { Jobs::CleanupArtifacts.new(config) }

      before do
        fake_locks
        allow(Config.cloud).to receive(:delete_stemcell)
        allow(Config.cloud).to receive(:delete_disk)

        stemcell_1 = Models::Stemcell.make(name: 'stemcell-a', operating_system: 'gentoo_linux', version: '1')
        Models::Stemcell.make(name: 'stemcell-b', version: '2')

        release_version_1 = Models::ReleaseVersion.make(version: 1, release: release_1)
        Models::ReleaseVersion.make(version: 2, release: release_2)

        package = Models::Package.make(release: release_1, blobstore_id: 'package_blob_id_1')
        package.add_release_version(release_version_1)
        Models::CompiledPackage.make(package: package, stemcell_os: stemcell_1.operating_system,
                                     stemcell_version: stemcell_1.version, blobstore_id: 'compiled-package-1')

        allow(Config).to receive(:event_log).and_return(event_log)
        allow(event_log).to receive(:begin_stage).and_return(stage)
        allow(stage).to receive(:advance_and_track).and_yield

        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)

        allow(blobstore).to receive(:delete).with('blobstore-id-1')
        allow(blobstore).to receive(:delete).with('package_blob_id_1')
      end

      context 'when cleaning up ALL artifacts (stemcells, releases AND orphaned disks)' do
        let(:config) { {'remove_all' => true } }
        before do
          expect(blobstore).to receive(:delete).with('compiled-package-1')
        end


        context 'when there are ephemeral blobs' do
          before do
            Bosh::Director::Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save
            Bosh::Director::Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_2', sha1: 'smurf2').save
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_1')
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_2')
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes them from blobstore and database' do
            expect(event_log).to receive(:begin_stage).with('Deleting ephemeral blobs', 2).and_return(stage)

            result = subject.perform

            expect(result).to eq('Deleted 2 release(s), 2 stemcell(s), 0 orphaned disk(s), 2 ephemeral blob(s)')
            expect(Models::EphemeralBlob.all).to be_empty
          end
        end

        context 'when there are orphaned disks' do
          before do
            Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
            Models::OrphanDisk.make(disk_cid: 'fake-cid-2')
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

            expect(result).to eq('Deleted 2 release(s), 2 stemcell(s), 2 orphaned disk(s), 0 ephemeral blob(s)')

            expect(Models::OrphanDisk.all).to be_empty
            expect(Models::Release.all).to be_empty
            expect(Models::Stemcell.all).to be_empty
          end
        end

        context 'when there are more than 2 stemcells and/or releases' do
          context 'and there are no orphaned disks' do
            it 'removes all stemcells and releases' do
              Models::Stemcell.make(name: 'stemcell-a', version: '10')
              Models::Stemcell.make(name: 'stemcell-b', version: '10')

              Models::ReleaseVersion.make(version: 10, release: release_1)
              Models::ReleaseVersion.make(version: 10, release: release_2)

              expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 4)
              expect(event_log).to receive(:begin_stage).with('Deleting releases', 4)

              allow(blobstore).to receive(:delete).with('package_blob_id_1')
              result = subject.perform

              expected_result = 'Deleted 4 release(s), 4 stemcell(s), 0 orphaned disk(s), 0 ephemeral blob(s)'
              expect(result).to eq(expected_result)

              expect(Models::Stemcell.all).to be_empty
              expect(Models::Release.all).to be_empty
            end
          end
        end
      end

      context 'when cleaning up only stemcells, releases, and ephemeral blobs' do
        let(:config) { {} }
        it 'logs and returns the result' do
          expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
          expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

          expect(thread_pool).not_to receive(:process)
          result = subject.perform

          expect(result).to eq('Deleted 0 release(s), 0 stemcell(s), 0 orphaned disk(s), 0 ephemeral blob(s)')

          expect(Models::Release.all.count).to eq(2)
          expect(Models::Stemcell.all.count).to eq(2)
        end

        context 'when there are more than 2 stemcells and/or releases' do
          it 'keeps the 2 latest versions of each stemcell' do
            expect(blobstore).not_to receive(:delete).with('compiled-package-1')

            Models::Stemcell.make(name: 'stemcell-a', version: '10')
            Models::Stemcell.make(name: 'stemcell-a', version: '9')
            Models::Stemcell.make(name: 'stemcell-b', version: '10')
            Models::Stemcell.make(name: 'stemcell-b', version: '9')

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

            expect(thread_pool).to receive(:process).exactly(2).times.and_yield
            result = subject.perform

            expected_result = 'Deleted 0 release(s), 2 stemcell(s), 0 orphaned disk(s), 0 ephemeral blob(s)'
            expect(result).to eq(expected_result)

            expect(Models::Stemcell.all.count).to eq(4)
            expect(Models::Release.all.count).to eq(2)
          end

          it 'keeps the last 2 most recently used releases' do
            expect(blobstore).to receive(:delete).with('compiled-package-1')

            Models::ReleaseVersion.make(version: 10, release: release_1)
            Models::ReleaseVersion.make(version: 10, release: release_2)
            Models::ReleaseVersion.make(version: 9, release: release_1)
            Models::ReleaseVersion.make(version: 9, release: release_2)

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 2)

            expect(thread_pool).to receive(:process).exactly(2).times.and_yield
            result = subject.perform

            expected_result = 'Deleted 2 release(s), 0 stemcell(s), 0 orphaned disk(s), 0 ephemeral blob(s)'
            expect(result).to eq(expected_result)

            expect(Models::Release.all.count).to eq(2)
            expect(Models::Stemcell.all.count).to eq(2)
          end
        end

        context 'when there are stemcells and releases in use' do
          before do
            deployment_1 = Models::Deployment.make(name: 'first')
            deployment_2 = Models::Deployment.make(name: 'second')

            stemcell_with_deployment_1 = Models::Stemcell.make(name: 'stemcell-c')
            stemcell_with_deployment_1.add_deployment(deployment_1)

            stemcell_with_deployment_2 = Models::Stemcell.make(name: 'stemcell-d')
            stemcell_with_deployment_2.add_deployment(deployment_2)

            release_1 = Models::Release.make(name: 'release-c')
            release_2 = Models::Release.make(name: 'release-d')
            version_1 = Models::ReleaseVersion.make(version: 1, release: release_1)
            version_2 = Models::ReleaseVersion.make(version: 2, release: release_2)

            version_1.add_deployment(deployment_1)
            version_2.add_deployment(deployment_2)
          end

          it 'does not delete any stemcells and releases currently in use' do
            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

            expect(thread_pool).not_to receive(:process)
            result = subject.perform

            expect(result).to eq('Deleted 0 release(s), 0 stemcell(s), 0 orphaned disk(s), 0 ephemeral blob(s)')

            expect(Models::Release.all.count).to eq(4)
            expect(Models::Stemcell.all.count).to eq(4)
          end
        end

        context 'when there are ephemeral blobs' do
          before do
            Bosh::Director::Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save
            Bosh::Director::Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_2', sha1: 'smurf2').save
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_1')
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_2')
            allow(event_log).to receive(:begin_stage).and_return(stage)
          end

          it 'deletes them from blobstore and database' do
            expect(event_log).to receive(:begin_stage).with('Deleting ephemeral blobs', 2).and_return(stage)

            result = subject.perform

            expect(result).to eq('Deleted 0 release(s), 0 stemcell(s), 0 orphaned disk(s), 2 ephemeral blob(s)')
            expect(Models::EphemeralBlob.all).to be_empty
          end
        end
      end

      context 'when director was unable to delete a disk' do
        let(:config) { {'remove_all' => true} }

        before do
          Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
          Models::OrphanDisk.make(disk_cid: 'fake-cid-2')
          expect(blobstore).to receive(:delete).with('compiled-package-1')
        end

        it 're-raises the error' do
          expect(Config.cloud).to receive(:delete_disk).and_raise(Exception.new('Bad stuff happened!'))

          expect {
            subject.perform
          }.to raise_error Exception, 'Bad stuff happened!'
        end
      end
      
      context 'when find_and_delete_release raises' do
        let(:config) { { 'remove_all' => true } }

        before do
          allow(blobstore).to receive(:delete).and_raise('nope')
          Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
          Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save
        end
        
        it 'does not delete stemcells, orphan disks and ephemeral blobs' do
          expect{ subject.perform }.to raise_error('nope')
          expect(Models::Stemcell.all).to_not be_empty
          expect(Models::OrphanDisk.all).to_not be_empty
          expect(Models::EphemeralBlob.all).to_not be_empty
        end
      end
    end
  end
end
