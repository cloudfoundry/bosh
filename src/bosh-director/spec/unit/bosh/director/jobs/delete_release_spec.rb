require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteRelease do
    let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }

    describe 'DJ job class expectations' do
      let(:job_type) { :delete_release }
      let(:queue) { :normal }
      it_behaves_like 'a DelayedJob job'
    end

    let(:release) { FactoryBot.create(:models_release, name: 'test_release') }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}

    before {
      allow(Config).to receive(:event_log).and_return(event_log)
    }

    describe 'perform' do
      context 'when blobstore fails to delete compiled package' do
        it 'should fail to delete release' do
          package = FactoryBot.create(:models_package, release: release)
          FactoryBot.create(:models_compiled_package, package: package, blobstore_id: 'compiled-package-1', stemcell_os: 'FreeBSD', stemcell_version: '10.1')

          expect(blobstore).to receive(:delete).with('compiled-package-1').and_raise('Oh noes!')

          job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
          expect(job).to receive(:with_release_lock).with('test_release', timeout: 10).and_yield

          expect { job.perform }.to raise_error 'Oh noes!'
        end
      end

      it 'should fail for unknown releases' do
        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        expect(job).to receive(:with_release_lock).with('test_release', timeout: 10).and_yield

        expect { job.perform }.to raise_exception(ReleaseNotFound)
      end

      it 'should fail if the deployments still reference this release' do
        version = FactoryBot.create(:models_release_version, release: release, version: '42-dev')
        deployment = FactoryBot.create(:models_deployment, name: 'test_release')

        deployment.add_release_version(version)

        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        expect(job).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        expect { job.perform }.to raise_exception(ReleaseInUse)
      end

      it 'should support deleting a particular release version' do
        rv1 = FactoryBot.create(:models_release_version, release: release, version: '1')
        FactoryBot.create(:models_release_version, release: release, version: '2')

        job = Jobs::DeleteRelease.new('test_release', 'version' => rv1.version, blobstore: blobstore)
        expect(job).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job.perform
      end

      it 'should fail deleting version if there is a deployment which ' +
           'uses that version' do
        rv1 = FactoryBot.create(:models_release_version, release: release, version: '1')
        rv2 = FactoryBot.create(:models_release_version, release: release, version: '2')

        manifest = YAML.dump('release' => {'name' => 'test_release', 'version' => '2'})

        deployment = FactoryBot.create(:models_deployment, name: 'test_deployment', manifest: manifest)
        deployment.add_release_version(rv2)

        job1 = Jobs::DeleteRelease.new('test_release', 'version' => '2', blobstore: blobstore)
        expect(job1).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield

        expect { job1.perform }.to raise_exception(ReleaseVersionInUse)

        job2 = Jobs::DeleteRelease.new('test_release', 'version' => '1', blobstore: blobstore)
        expect(job2).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job2.perform
      end
    end

    describe 'delete release version' do
      before(:each) do
        @rv1 = FactoryBot.create(:models_release_version, release: release)
        @rv2 = FactoryBot.create(:models_release_version, release: release)

        @pkg1 = FactoryBot.create(:models_package, release: release, blobstore_id: 'pkg1')
        @pkg2 = FactoryBot.create(:models_package, release: release, blobstore_id: 'pkg2')
        @pkg3 = FactoryBot.create(:models_package, release: release, blobstore_id: 'pkg3')

        @tmpl1 = FactoryBot.create(:models_template, release: release, blobstore_id: 'template1')
        @tmpl2 = FactoryBot.create(:models_template, release: release, blobstore_id: 'template2')
        @tmpl3 = FactoryBot.create(:models_template, release: release, blobstore_id: 'template3')

        @stemcell = FactoryBot.create(:models_stemcell, operating_system: 'linux', version: '3.11')

        @cpkg1 = FactoryBot.create(:models_compiled_package, package: @pkg1, blobstore_id: 'deadbeef', stemcell_os: @stemcell.operating_system, stemcell_version: @stemcell.version)
        @cpkg2 = FactoryBot.create(:models_compiled_package, package: @pkg2, blobstore_id: 'badcafe', stemcell_os: @stemcell.operating_system, stemcell_version: @stemcell.version)
        @cpkg3 = FactoryBot.create(:models_compiled_package, package: @pkg3, blobstore_id: 'feeddead', stemcell_os: @stemcell.operating_system, stemcell_version: @stemcell.version)

        @rv1.add_package(@pkg1)
        @rv1.add_package(@pkg2)
        @rv1.add_package(@pkg3)

        @rv2.add_package(@pkg1)
        @rv2.add_package(@pkg2)

        @rv1.add_template(@tmpl1)
        @rv1.add_template(@tmpl2)
        @rv1.add_template(@tmpl3)

        @rv2.add_template(@tmpl1)
        @rv2.add_template(@tmpl2)
      end

      it 'should delete release version without touching any shared packages/templates' do
        job = Jobs::DeleteRelease.new('test_release', 'version' => @rv1.version, blobstore: blobstore)

        expect(blobstore).to receive(:delete).with('pkg3')
        expect(blobstore).to receive(:delete).with('template3')
        expect(blobstore).to receive(:delete).with('feeddead')
        expect(job).to receive(:with_release_lock).with('test_release', timeout: 10).and_yield
        job.perform

        expect(Models::ReleaseVersion[@rv1.id]).to be_nil
        expect(Models::ReleaseVersion[@rv2.id]).not_to be_nil

        expect(Models::Package[@pkg1.id]).to eq(@pkg1)
        expect(Models::Package[@pkg2.id]).to eq(@pkg2)
        expect(Models::Package[@pkg3.id]).to be_nil

        expect(Models::Template[@tmpl1.id]).to eq(@tmpl1)
        expect(Models::Template[@tmpl2.id]).to eq(@tmpl2)
        expect(Models::Template[@tmpl3.id]).to be_nil

        expect(Models::CompiledPackage[@cpkg1.id]).to eq(@cpkg1)
        expect(Models::CompiledPackage[@cpkg2.id]).to eq(@cpkg2)
        expect(Models::CompiledPackage[@cpkg3.id]).to be_nil
      end

      it 'should not leave any release/package/templates artifacts after all ' +
           'release versions have been deleted' do
        job1 = Jobs::DeleteRelease.new('test_release', 'version' => @rv1.version, blobstore: blobstore)
        job2 = Jobs::DeleteRelease.new('test_release', 'version' => @rv2.version, blobstore: blobstore)

        allow(blobstore).to receive(:delete)

        expect(job1).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job1.perform

        expect(Models::Release.count).to eq(1)

        # This assertion is very important as SQLite doesn't check integrity
        # but Postgres does and it can fail on postgres if there are any hanging
        # references to release version in packages_release_versions
        expect(Models::Package.db[:packages_release_versions].count).to eq(2)

        expect(job2).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job2.perform

        expect(Models::ReleaseVersion.count).to eq(0)
        expect(Models::Package.count).to eq(0)
        expect(Models::Template.count).to eq(0)
        expect(Models::CompiledPackage.count).to eq(0)
        expect(Models::Release.count).to eq(0)
      end
    end
  end
end
