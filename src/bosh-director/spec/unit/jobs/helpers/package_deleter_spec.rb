require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe PackageDeleter do
      subject(:package_deleter) { PackageDeleter.new(compiled_package_deleter, blobstore, logger) }
      let(:event_log) { EventLog::Log.new }
      let(:compiled_package_deleter) { CompiledPackageDeleter.new(blobstore, logger) }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      before { allow(blobstore).to receive(:delete) }
      let(:release_version_1) { Models::ReleaseVersion.make() }
      let(:release_version_2) { Models::ReleaseVersion.make() }
      let(:package) { Models::Package.make(blobstore_id: 'package_blobstore_id') }

      before do
        package.add_release_version(release_version_1)
        package.add_release_version(release_version_2)
        Models::CompiledPackage.make(package: package, blobstore_id: 'compiled_package_blobstore_id', stemcell_os: 'Darwin', stemcell_version: 'X')
        Models::CompiledPackage.make(package: package, stemcell_os: 'Darwin', stemcell_version: 'Y')
      end

      describe '#delete' do
        context 'when not forced' do
          let(:force) { false }
          it 'should delete the packages blob' do
            expect(blobstore).to receive(:delete).with('package_blobstore_id')
            package_deleter.delete(package, force)
          end

          it 'should delete the package' do
            package_deleter.delete(package, force)
            expect(Models::Package.where(blobstore_id: 'package_blobstore_id')).to be_empty
          end

          it "should remove the package's release version associations" do
            package_deleter.delete(package, force)
            expect(release_version_1.packages).to be_empty
            expect(release_version_2.packages).to be_empty
          end

          it "should delete the package's compiled packages" do
            package_deleter.delete(package, force)
            expect(Models::CompiledPackage.all).to be_empty
          end

          context 'when the package does not have source blobs and only contains compiled packages (and therefore the blobstore id is nil)' do
            before do
              package.update(blobstore_id: nil, sha1: nil)
              allow(blobstore).to receive(:delete).with(nil).and_raise('cant')
            end

            it 'deletes the package model' do
              package_deleter.delete(package, force)
              expect(Models::Package.all).to be_empty
            end
          end

          context 'when failing to delete the compiled package' do
            before do
              allow(blobstore).to receive(:delete).with('compiled_package_blobstore_id').and_raise('negative')
            end

            it 'should raise' do
              expect { package_deleter.delete(package, force) }.to raise_error(/negative/)
            end
          end

          context 'when failing to delete the package blob' do
            before do
              allow(blobstore).to receive(:delete).with('package_blobstore_id').and_raise('negative')
            end

            it 'should raise' do
              expect { package_deleter.delete(package, force) }.to raise_error(/negative/)
            end
          end
        end

        context 'when forced' do
          let(:force) { true }

          context 'when deleting package from blobstore fails' do
            before do
              allow(blobstore).to receive(:delete).with('package_blobstore_id').and_raise('negative')
            end

            it 'deletes package model' do
              package_deleter.delete(package, force)
              expect(Models::Package.all).to be_empty
            end

            it "should remove the package's release version associations" do
              package_deleter.delete(package, force)
              expect(release_version_1.packages).to be_empty
              expect(release_version_2.packages).to be_empty
            end

            it "should delete the package's compiled packages" do
              package_deleter.delete(package, force)
              expect(Models::CompiledPackage.all).to be_empty
            end
          end

          context 'when failing to delete the compiled package' do
            before do
              allow(blobstore).to receive(:delete).with('compiled_package_blobstore_id').and_raise('negative')
            end

            # if the compiled package is not deleted successfully, the package will fail to destroy.
            # if we destroy the compiled package despite failing to delete it's blob, we lose the
            # ability to delete the blob in the future.
            it 'continues to delete the package' do
              package_deleter.delete(package, force)
              expect(Models::Package.all).to be_empty
            end

            it "should remove the package's release version associations" do
              package_deleter.delete(package, force)
              expect(release_version_1.packages).to be_empty
              expect(release_version_2.packages).to be_empty
            end

            it "should delete the package's compiled packages" do
              package_deleter.delete(package, force)
              expect(Models::CompiledPackage.all).to be_empty
            end
          end
        end
      end
    end
  end
end
