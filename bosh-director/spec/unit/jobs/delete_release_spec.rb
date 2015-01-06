# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteRelease do
    let(:blobstore) { double('Blobstore') }

    describe 'Resque job class expectations' do
      let(:job_type) { :delete_release }
      it_behaves_like 'a Resque job'
    end

    describe 'perform' do
      it 'should fail for unknown releases' do
        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        expect(job).to receive(:with_release_lock).with('test_release', timeout: 10).and_yield

        expect { job.perform }.to raise_exception(ReleaseNotFound)
      end

      it 'should fail if the deployments still reference this release' do
        release = Models::Release.make(name: 'test')
        version = Models::ReleaseVersion.make(release: release, version: '42-dev')
        deployment = Models::Deployment.make(name: 'test')

        deployment.add_release_version(version)

        job = Jobs::DeleteRelease.new('test', blobstore: blobstore)
        expect(job).to receive(:with_release_lock).
          with('test', timeout: 10).and_yield
        expect { job.perform }.to raise_exception(ReleaseInUse)
      end

      it 'should delete the release and associated jobs, packages, compiled packages and their metadata' do
        release = Models::Release.make(name: 'test_release')

        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        expect(job).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        expect(job).to receive(:delete_release).with(release)
        job.perform
      end

      it 'should fail if the delete was not successful' do
        release = Models::Release.make(name: 'test_release')

        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        expect(job).to receive(:delete_release).with(release)
        expect(job).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job.instance_eval { @errors << 'bad' }
        expect { job.perform }.to raise_exception
      end

      it 'should support deleting a particular release version' do
        release = Models::Release.make(name: 'test_release')
        rv1 = Models::ReleaseVersion.make(release: release, version: '1')
        Models::ReleaseVersion.make(release: release, version: '2')

        job = Jobs::DeleteRelease.new('test_release', 'version' => rv1.version, blobstore: blobstore)
        expect(job).to receive(:delete_release_version).with(rv1)
        expect(job).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        job.perform
      end

      it 'should fail deleting version if there is a deployment which ' +
           'uses that version' do
        release = Models::Release.make(name: 'test_release')
        rv1 = Models::ReleaseVersion.make(release: release, version: '1')
        rv2 = Models::ReleaseVersion.make(release: release, version: '2')

        manifest = Psych.dump('release' => {'name' => 'test_release', 'version' => '2'})

        deployment = Models::Deployment.make(name: 'test_deployment', manifest: manifest)
        deployment.add_release_version(rv2)

        job1 = Jobs::DeleteRelease.new('test_release', 'version' => '2', blobstore: blobstore)
        expect(job1).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield

        expect { job1.perform }.to raise_exception(ReleaseVersionInUse)

        job2 = Jobs::DeleteRelease.new('test_release', 'version' => '1', blobstore: blobstore)
        expect(job2).to receive(:with_release_lock).
          with('test_release', timeout: 10).and_yield
        expect(job2).to receive(:delete_release_version).with(rv1)
        job2.perform
      end

    end

    describe 'delete_release' do

      before(:each) do
        @release = Models::Release.make(name: 'test_release')
        @release_version = Models::ReleaseVersion.make(release: @release)
        @package = Models::Package.make(release: @release, blobstore_id: 'package-blb')
        @template = Models::Template.make(release: @release, blobstore_id: 'template-blb')
        @stemcell = Models::Stemcell.make
        @compiled_package =
          Models::CompiledPackage.make(package: @package, stemcell: @stemcell, blobstore_id: 'compiled-package-blb')
        @release_version.add_package(@package)
        @release_version.add_template(@template)
      end

      it 'should delete release and associated objects/meta' do
        expect(blobstore).to receive(:delete).with('template-blb')
        expect(blobstore).to receive(:delete).with('package-blb')
        expect(blobstore).to receive(:delete).with('compiled-package-blb')

        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        job.delete_release(@release)

        expect(job.instance_eval { @errors }).to be_empty

        expect(Models::Release[@release.id]).to be_nil
        expect(Models::ReleaseVersion[@release_version.id]).to be_nil
        expect(Models::Package[@package.id]).to be_nil
        expect(Models::Template[@template.id]).to be_nil
        expect(Models::CompiledPackage[@compiled_package.id]).to be_nil
      end

      it 'should fail to delete the release if there is a blobstore error' do
        expect(blobstore).to receive(:delete).with('template-blb').and_raise('bad')
        expect(blobstore).to receive(:delete).with('package-blb')
        expect(blobstore).to receive(:delete).with('compiled-package-blb')

        job = Jobs::DeleteRelease.new('test_release', blobstore: blobstore)
        job.delete_release(@release)

        errors = job.instance_eval { @errors }
        expect(errors.length).to eql(1)
        expect(errors.first.to_s).to eql('bad')

        expect(Models::Release[@release.id]).not_to be_nil
        expect(Models::ReleaseVersion[@release_version.id]).not_to be_nil
        expect(Models::Package[@package.id]).to be_nil
        expect(Models::Template[@template.id]).not_to be_nil
        expect(Models::CompiledPackage[@compiled_package.id]).to be_nil
      end

      it 'should forcefully delete the release when requested even if there is a blobstore error' do
        expect(blobstore).to receive(:delete).with('template-blb').and_raise('bad')
        expect(blobstore).to receive(:delete).with('package-blb')
        expect(blobstore).to receive(:delete).with('compiled-package-blb')

        job = Jobs::DeleteRelease.new('test_release', 'force' => true, blobstore: blobstore)
        job.delete_release(@release)

        errors = job.instance_eval { @errors }
        expect(errors.length).to eql(1)
        expect(errors.first.to_s).to eql('bad')

        expect(Models::Release[@release.id]).to be_nil
        expect(Models::ReleaseVersion[@release_version.id]).to be_nil
        expect(Models::Package[@package.id]).to be_nil
        expect(Models::Template[@template.id]).to be_nil
        expect(Models::CompiledPackage[@compiled_package.id]).to be_nil
      end

    end

    describe 'delete release version' do
      before(:each) do
        @release = Models::Release.make(name: 'test_release')

        @rv1 = Models::ReleaseVersion.make(release: @release)
        @rv2 = Models::ReleaseVersion.make(release: @release)

        @pkg1 = Models::Package.make(release: @release, blobstore_id: 'pkg1')
        @pkg2 = Models::Package.make(release: @release, blobstore_id: 'pkg2')
        @pkg3 = Models::Package.make(release: @release, blobstore_id: 'pkg3')

        @tmpl1 = Models::Template.make(release: @release, blobstore_id: 'template1')
        @tmpl2 = Models::Template.make(release: @release, blobstore_id: 'template2')
        @tmpl3 = Models::Template.make(release: @release, blobstore_id: 'template3')

        @stemcell = Models::Stemcell.make

        @cpkg1 = Models::CompiledPackage.make(package: @pkg1, stemcell: @stemcell, blobstore_id: 'deadbeef')
        @cpkg2 = Models::CompiledPackage.make(package: @pkg2, stemcell: @stemcell, blobstore_id: 'badcafe')
        @cpkg3 = Models::CompiledPackage.make(package: @pkg3, stemcell: @stemcell, blobstore_id: 'feeddead')

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

        job.delete_release_version(@rv1)

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
