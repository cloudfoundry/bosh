require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::CompiledPackageDeleter do
    subject(:package_deleter) { Jobs::Helpers::CompiledPackageDeleter.new(blob_deleter, logger) }
    let(:blob_deleter) { Jobs::Helpers::BlobDeleter.new(blobstore, logger) }
    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
    let(:event_log) { EventLog::Log.new }

    describe '#delete' do
      it 'deletes the compiled package' do
        compiled_package = Models::CompiledPackage.make(
          package: Models::Package.make(name: 'package-name', version: 'version'),
          blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

        expect(blobstore).to receive(:delete).with('compiled-package-blb-1')

        expect(package_deleter.delete(compiled_package)).to be_empty
        expect(Models::CompiledPackage.all).to be_empty
      end

      context 'when it fails to delete the compiled package in the blobstore' do
        before do
          allow(blobstore).to receive(:delete).and_raise("Failed to delete")
        end

        it 'returns an error AND does not delete the compiled package from the database' do
          compiled_package = Models::CompiledPackage.make(
            package: Models::Package.make(name: 'package-name', version: 'version'),
            blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

          errors = package_deleter.delete(compiled_package)
          expect(errors.count).to eq(1)
          expect(Models::CompiledPackage[compiled_package.id]).not_to be_nil
        end

        context 'when force is true' do
          it 'deletes the compiled package from the database' do
            compiled_package = Models::CompiledPackage.make(
              package: Models::Package.make(name: 'package-name', version: 'version'),
              blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

            package_deleter.delete(compiled_package, {'force' => true})
            expect(Models::CompiledPackage.all).to be_empty
          end

          it 'does not raise error' do
            compiled_package = Models::CompiledPackage.make(
              package: Models::Package.make(name: 'package-name', version: 'version'),
              blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

            expect { package_deleter.delete(compiled_package, {'force' => true}) }.not_to raise_error
          end
        end
      end
    end
  end
end
