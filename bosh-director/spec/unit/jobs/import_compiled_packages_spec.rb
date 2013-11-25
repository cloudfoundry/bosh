require 'spec_helper'
require 'bosh/director/jobs/import_compiled_packages'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe Jobs::ImportCompiledPackages do
    describe 'Resque job class expectations' do
      let(:job_type) { :import_compiled_packages } # because the shared example needs it
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      include FakeFS::SpecHelpers

      subject(:import_job) { described_class.new(export_dir) }
      before { Bosh::Director::App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client) }

      let(:export_dir) { '/tmp/export/dir' }
      let(:exported_tar) { asset('bosh-release-0.1-dev-ubuntu-stemcell-1.tgz') }
      let(:export) { instance_double('Bosh::Director::CompiledPackage::CompiledPackagesExport') }
      let(:blobstore_client) { double('blobstore client') }

      let(:package1) do
        instance_double('Bosh::Director::CompiledPackage::CompiledPackage',
                        name: 'package1',
                        blobstore_id: 'blob-id1',
                        blob_path: '/tmp/blob1',
                        package_fingerprint: 'package-fingerprint1',
                        stemcell_sha1: 'stemcell-sha1',
                        sha1: 'test-sha1-1',
                        check_blob_sha: nil
        )
      end

      let(:package2) do
        instance_double('Bosh::Director::CompiledPackage::CompiledPackage',
                        name: 'package2',
                        blobstore_id: 'blob-id2',
                        blob_path: '/tmp/blob2',
                        package_fingerprint: 'package-fingerprint2',
                        stemcell_sha1: 'stemcell-sha1',
                        sha1: 'test-sha1-2',
                        check_blob_sha: nil
        )
      end

      let(:manifest) {
        {
          'release_name' => 'test-release-name',
          'release_version' => 'test-release-version',
          'release_commit_hash' => 'test-commit-hash',
        }
      }

      let(:package_model1) do
        Bosh::Director::Models::Package.make(
          release: release,
          name: package1.name,
          fingerprint: package1.package_fingerprint,
        )
      end

      let(:package_model2) do
        Bosh::Director::Models::Package.make(
          release: release,
          name: package2.name,
          fingerprint: package2.package_fingerprint,
          dependency_set_json: Yajl::Encoder.encode([package1.name]))
      end

      let!(:stemcell) { Bosh::Director::Models::Stemcell.make(sha1: package1.stemcell_sha1) }
      let(:release) do
        Bosh::Director::Models::Release.make(name: manifest['release_name'])
      end
      let(:inserter) { instance_double('Bosh::Director::CompiledPackage::CompiledPackageInserter') }

      let(:release_version) do
        Bosh::Director::Models::ReleaseVersion.make(
          release: release,
          version: manifest['release_version'],
        )
      end

      before do

        Bosh::Director::CompiledPackage::CompiledPackagesExport.stub(:new).with(
          file: '/tmp/export/dir/compiled_packages_export.tgz').and_return(export)
        export.stub(:extract).and_yield(manifest, [package1, package2])

        FileUtils.mkpath(export_dir)
      end

      context 'when there is one Release and one ReleaseVersion' do
        before do
          release_version.add_package(package_model1)
          release_version.add_package(package_model2)

          Bosh::Director::CompiledPackage::CompiledPackageInserter.stub(new: inserter)
          inserter.stub(:insert)
        end

        it 'creates a CompiledPackageInserter' do
          expect(Bosh::Director::CompiledPackage::CompiledPackageInserter).to receive(:new).with(blobstore_client)

          import_job.perform
          expect(inserter).to have_received(:insert).with(package1, release_version)
          expect(inserter).to have_received(:insert).with(package2, release_version)
        end

        it 'extracts the export' do
          expect(export).to receive(:extract)
          import_job.perform
        end

        it 'checks the blob integrity' do
          package1.should_receive(:check_blob_sha)
          package2.should_receive(:check_blob_sha)

          import_job.perform
        end

        it 'cleans up the temp dir' do
          expect(FileUtils).to receive(:rm_rf).with(export_dir)
          import_job.perform
        end
      end

      context 'when there are multiple release versions' do
        before do
          Bosh::Director::CompiledPackage::CompiledPackageInserter.stub(new: inserter)
          inserter.stub(:insert)

          Bosh::Director::Models::Release.make(
            name: 'another_release',
          ).add_version(version: 'test-release-version')

          release_version.add_package(package_model1)
          release_version.add_package(package_model2)
        end

        it 'inserts each package with the inserter' do
          import_job.perform

          expect(inserter).to have_received(:insert).with(package1, release_version)
        end
      end

      context 'when an exception is raised in perform' do
        it 'cleans up the temp dir' do
          export.stub(:extract).and_raise(StandardError, 'fff')

          expect { import_job.perform }.to raise_error(StandardError, 'fff')
          expect(File.exist?(export_dir)).to be(false)
        end
      end

      def find_compiled_package(package_model, stemcell_id, dependencies)
        dependency_array = dependencies.map { |package_model| [package_model.name, package_model.version] }

        Bosh::Director::Models::CompiledPackage[
          package_id: package_model.id,
          stemcell_id: stemcell_id,
          dependency_key: Yajl::Encoder.encode(dependency_array)
        ]
      end
    end
  end
end
