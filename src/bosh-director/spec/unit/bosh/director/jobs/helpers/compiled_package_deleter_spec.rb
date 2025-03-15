require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::CompiledPackageDeleter do
    subject(:compiled_package_deleter) { Jobs::Helpers::CompiledPackageDeleter.new(blobstore, per_spec_logger) }
    let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }
    let(:event_log) { EventLog::Log.new }

    describe '#delete' do
      it 'deletes the compiled package' do
        compiled_package = FactoryBot.create(:models_compiled_package,
          package: FactoryBot.create(:models_package, name: 'package-name', version: 'version'),
          blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

        expect(blobstore).to receive(:delete).with('compiled-package-blb-1')

        compiled_package_deleter.delete(compiled_package)

        expect(Models::CompiledPackage.all).to be_empty
      end

      context 'when it fails to delete the compiled package in the blobstore' do
        before do
          allow(blobstore).to receive(:delete).and_raise("Failed to delete")
        end

        it 'raises an error AND does not delete the compiled package from the database' do
          compiled_package = FactoryBot.create(:models_compiled_package,
            package: FactoryBot.create(:models_package, name: 'package-name', version: 'version'),
            blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

          expect{ compiled_package_deleter.delete(compiled_package) }.to raise_error(/Failed to delete/)
          expect(Models::CompiledPackage[compiled_package.id]).not_to be_nil
        end

        context 'when force is true' do
          it 'deletes the compiled package from the database' do
            compiled_package = FactoryBot.create(:models_compiled_package,
              package: FactoryBot.create(:models_package, name: 'package-name', version: 'version'),
              blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

            compiled_package_deleter.delete(compiled_package, true)
            expect(Models::CompiledPackage.all).to be_empty
          end

          it 'does not raise error' do
            compiled_package = FactoryBot.create(:models_compiled_package,
              package: FactoryBot.create(:models_package, name: 'package-name', version: 'version'),
              blobstore_id: 'compiled-package-blb-1', stemcell_os: 'linux', stemcell_version: '2.6.11')

            expect { compiled_package_deleter.delete(compiled_package, true) }.not_to raise_error
          end
        end
      end
    end
  end
end
