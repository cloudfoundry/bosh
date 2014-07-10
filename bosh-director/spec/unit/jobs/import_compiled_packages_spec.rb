require 'spec_helper'
require 'bosh/director/jobs/import_compiled_packages'

module Bosh::Director
  describe Jobs::ImportCompiledPackages do
    describe 'Resque job class expectations' do
      let(:job_type) { :import_compiled_packages }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      subject(:import_job) { described_class.new(compiled_packages_path) }
      let(:compiled_packages_path) { '/tmp/fake-export.tgz' }

      before { Bosh::Director::App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client) }
      let(:blobstore_client) { instance_double('Bosh::Blobstore::BaseClient') }

      let(:export) { instance_double('Bosh::Director::CompiledPackage::CompiledPackagesExport') }
      before do
        allow(Bosh::Director::CompiledPackage::CompiledPackagesExport).to receive(:new).
          with(file: compiled_packages_path).
          and_return(export)
      end

      before { allow(export).to receive(:extract).and_yield(manifest, [package1, package2]) }

      let(:manifest) do
        {
          'release_name' => 'test-release-name',
          'release_version' => 'test-release-version',
          'release_commit_hash' => 'test-commit-hash',
        }
      end

      let(:package1) do
        instance_double('Bosh::Director::CompiledPackage::CompiledPackage', {
          package_name: 'package1',
          blobstore_id: 'blob-id1',
          blob_path: '/tmp/blob1',
          package_fingerprint: 'package-fingerprint1',
          stemcell_sha1: 'stemcell-sha1',
          sha1: 'test-sha1-1',
          check_blob_sha: nil
        })
      end

      let(:package2) do
        instance_double('Bosh::Director::CompiledPackage::CompiledPackage', {
          package_name: 'package2',
          blobstore_id: 'blob-id2',
          blob_path: '/tmp/blob2',
          package_fingerprint: 'package-fingerprint2',
          stemcell_sha1: 'stemcell-sha1',
          sha1: 'test-sha1-2',
          check_blob_sha: nil
        })
      end

      context 'when release (not release version) is found' do
        let(:release) { Bosh::Director::Models::Release.make(name: manifest['release_name']) }

        context 'when release version is found' do
          let!(:release_version) do
            Bosh::Director::Models::ReleaseVersion.make(
              release: release,
              version: manifest['release_version'],
            )
          end

          before { release_version.add_package(package_model1) }
          let(:package_model1) do
            Bosh::Director::Models::Package.make(
              release: release,
              name: package1.package_name,
              fingerprint: package1.package_fingerprint,
            )
          end

          before { release_version.add_package(package_model2) }
          let(:package_model2) do
            Bosh::Director::Models::Package.make(
              release: release,
              name: package2.package_name,
              fingerprint: package2.package_fingerprint,
              dependency_set_json: Yajl::Encoder.encode([package1.package_name]),
            )
          end

          before { allow(Bosh::Director::CompiledPackage::CompiledPackageInserter).to receive(:new).with(blobstore_client).and_return(inserter) }
          let(:inserter) { instance_double('Bosh::Director::CompiledPackage::CompiledPackageInserter', insert: nil) }

          it 'inserts compiled packages for a release version' do
            expect(inserter).to receive(:insert).with(package1, release_version)
            expect(inserter).to receive(:insert).with(package2, release_version)
            import_job.perform
          end

          it 'checks the blob integrity' do
            package1.should_receive(:check_blob_sha)
            package2.should_receive(:check_blob_sha)
            import_job.perform
          end

          it 'cleans up the compiled packages path' do
            expect(FileUtils).to receive(:rm_rf).with(compiled_packages_path)
            import_job.perform
          end
        end

        context 'when release version is not found' do
          before { Bosh::Director::Models::ReleaseVersion.make(release: release, version: 'other-version') }

          it 'raises an ReleaseVersionNotFound error' do
            expect { import_job.perform }.to raise_error(ReleaseVersionNotFound)
          end
        end
      end

      context 'when release (not release version) is not found' do
        it 'raises an ReleaseVersionNotFound error' do
          expect { import_job.perform }.to raise_error(ReleaseNotFound)
        end
      end

      context 'when extracting compiled packages archive fails' do
        it 'cleans up compiled packages path' do
          error = StandardError.new
          allow(export).to receive(:extract).and_raise(error)

          expect(FileUtils).to receive(:rm_rf).with(compiled_packages_path)
          expect { import_job.perform }.to raise_error(error)
        end
      end
    end
  end
end
