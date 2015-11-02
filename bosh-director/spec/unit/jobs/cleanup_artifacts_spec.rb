require 'spec_helper'

module Bosh::Director
  describe Jobs::CleanupArtifacts do

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }

      it 'enqueues a CleanupArtifacts job' do
        fake_config = {'remove_all' => true}

        expect(job_queue).to receive(:enqueue).with('fake-username', Jobs::CleanupArtifacts, 'delete artifacts', [fake_config])
        Jobs::CleanupArtifacts.enqueue('fake-username', fake_config, job_queue)
      end
    end

    describe '#perform' do
      let(:event_log){ EventLog::Log.new }
      let(:cloud){ instance_double(Bosh::Cloud) }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      let(:release_1) { Models::Release.make(name: 'release-1') }
      let(:release_2) { Models::Release.make(name: 'release-2') }

      before do
        fake_locks
        allow(cloud).to receive(:delete_stemcell)

        stemcell_1 = Models::Stemcell.make(name: 'stemcell-a', version: '1')
        Models::Stemcell.make(name: 'stemcell-b', version: '2')

        release_version_1 = Models::ReleaseVersion.make(version: 1, release: release_1)
        Models::ReleaseVersion.make(version: 2, release: release_2)

        package = Models::Package.make(release: release_1, blobstore_id: 'package_blob_id_1')
        package.add_release_version(release_version_1)
        Models::CompiledPackage.make(package: package, stemcell: stemcell_1, blobstore_id: 'compiled-package-1')

        allow(Config).to receive(:event_log).and_return(event_log)
        allow(event_log).to receive(:begin_stage)

        allow(Config).to receive(:cloud).and_return(cloud)
        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)

        allow(blobstore).to receive(:delete).with('compiled-package-1')
        allow(blobstore).to receive(:delete).with('blobstore-id-1')
      end

      context 'when cleaning up ALL artifacts (stemcells, releases AND orphaned disks)' do
        context 'when there are orphaned disks' do
         before do
           Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
           Models::OrphanDisk.make(disk_cid: 'fake-cid-2')
           allow(blobstore).to receive(:delete).with('package_blob_id_1')
         end

         it 'logs and returns the result' do
           expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2)
           expect(event_log).to receive(:begin_stage).with('Deleting releases', 2)
           expect(event_log).to receive(:begin_stage).with('Deleting orphaned disks', 2)

           allow(cloud).to receive(:delete_disk)

           config = {'remove_all' => true}
           delete_artifacts = Jobs::CleanupArtifacts.new(config)
           expect_any_instance_of(ThreadPool).to receive(:process).exactly(6).times.and_call_original
           result = delete_artifacts.perform

           expect(result).to eq('stemcell(s) deleted: stemcell-a/1, stemcell-b/2; release(s) deleted: release-1/1, release-2/2; orphaned disk(s) deleted: fake-cid-1, fake-cid-2')

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

              allow(cloud).to receive(:delete_disk)
              allow(blobstore).to receive(:delete).with('package_blob_id_1')
              delete_artifacts = Jobs::CleanupArtifacts.new({'remove_all' => true})
              expect_any_instance_of(ThreadPool).to receive(:process).exactly(8).times.and_call_original
              result = delete_artifacts.perform

              expected_result = 'stemcell(s) deleted: stemcell-a/1, stemcell-a/10, stemcell-b/2, stemcell-b/10; release(s) deleted: release-1/1, release-1/10, release-2/2, release-2/10; orphaned disk(s) deleted: none'
              expect(result).to eq(expected_result)

              expect(Models::Stemcell.all).to be_empty
              expect(Models::Release.all).to be_empty
            end
          end
        end
      end

      context 'when cleaning up only stemcells and releases' do
        it 'logs and returns the result' do
          expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
          expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

          allow(cloud).to receive(:delete_disk)

          delete_artifacts = Jobs::CleanupArtifacts.new({})
          expect_any_instance_of(ThreadPool).not_to receive(:process)
          result = delete_artifacts.perform

          expect(result).to eq('stemcell(s) deleted: none; release(s) deleted: none')

          expect(Models::Release.all.count).to eq(2)
          expect(Models::Stemcell.all.count).to eq(2)
        end

        context 'when there are more than 2 stemcells and/or releases' do
          it 'keeps the 2 latest versions of each stemcell' do
            Models::Stemcell.make(name: 'stemcell-a', version: '10')
            Models::Stemcell.make(name: 'stemcell-a', version: '9')
            Models::Stemcell.make(name: 'stemcell-b', version: '10')
            Models::Stemcell.make(name: 'stemcell-b', version: '9')

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 2)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 0)

            allow(cloud).to receive(:delete_disk)

            delete_artifacts = Jobs::CleanupArtifacts.new({})
            expect_any_instance_of(ThreadPool).to receive(:process).exactly(2).times.and_call_original
            result = delete_artifacts.perform

            expected_result = 'stemcell(s) deleted: stemcell-a/1, stemcell-b/2; release(s) deleted: none'
            expect(result).to eq(expected_result)

            expect(Models::Stemcell.all.count).to eq(4)
            expect(Models::Release.all.count).to eq(2)
          end

          it 'keeps the last 2 most recently used releases' do
            Models::ReleaseVersion.make(version: 10, release: release_1)
            Models::ReleaseVersion.make(version: 10, release: release_2)
            Models::ReleaseVersion.make(version: 9, release: release_1)
            Models::ReleaseVersion.make(version: 9, release: release_2)

            expect(event_log).to receive(:begin_stage).with('Deleting stemcells', 0)
            expect(event_log).to receive(:begin_stage).with('Deleting releases', 2)

            allow(cloud).to receive(:delete_disk)

            delete_artifacts = Jobs::CleanupArtifacts.new({})
            expect_any_instance_of(ThreadPool).to receive(:process).exactly(2).times.and_call_original
            result = delete_artifacts.perform

            expected_result = 'stemcell(s) deleted: none; release(s) deleted: release-1/1, release-2/2'
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

            allow(cloud).to receive(:delete_disk)

            delete_artifacts = Jobs::CleanupArtifacts.new({})
            expect_any_instance_of(ThreadPool).not_to receive(:process)
            result = delete_artifacts.perform

            expect(result).to eq('stemcell(s) deleted: none; release(s) deleted: none')

            expect(Models::Release.all.count).to eq(4)
            expect(Models::Stemcell.all.count).to eq(4)
          end
        end
      end

      context 'when director was unable to delete a disk' do
        before do
          Models::OrphanDisk.make(disk_cid: 'fake-cid-1')
          Models::OrphanDisk.make(disk_cid: 'fake-cid-2')
        end
        it 're-raises the error' do
          allow(cloud).to receive(:delete_disk).and_raise(Exception.new('Bad stuff happened!'))

          config = {'remove_all' => true}
          delete_artifacts = Jobs::CleanupArtifacts.new(config)
          expect {
            delete_artifacts.perform
          }.to raise_error Exception, 'Bad stuff happened!'
        end
      end
    end
  end
end
