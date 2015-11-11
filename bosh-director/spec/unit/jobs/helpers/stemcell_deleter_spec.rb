require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::StemcellDeleter do
    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
    let(:event_log) { EventLog::Log.new }
    let(:blob_deleter) { Jobs::Helpers::BlobDeleter.new(blobstore, logger) }
    let(:cloud) { instance_double(Bosh::Cloud) }
    let(:package_deleter) { Jobs::Helpers::CompiledPackageDeleter.new(blob_deleter, logger)}
    let(:stemcell_deleter) { Jobs::Helpers::StemcellDeleter.new(cloud, package_deleter, logger, event_log) }
    let(:stemcell) { Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid') }

    before do
      fake_locks
      allow(Config).to receive(:cloud).and_return(cloud)
      allow(event_log).to receive(:begin_stage).and_call_original
      allow(event_log).to receive(:track).and_call_original
    end

    context 'when stemcell deletion fails' do
      it "should raise error if CPI can't delete the stemcell" do
        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')

        expect {
          stemcell_deleter.delete(stemcell)
        }.to raise_error
      end

      it 'should raise error if the deployments still reference this stemcell' do
        deployment_1 = Models::Deployment.make(name: 'test-1')
        deployment_1.add_stemcell(stemcell)
        deployment_2 = Models::Deployment.make(name: 'test-2')
        deployment_2.add_stemcell(stemcell)

        expect {
          stemcell_deleter.delete(stemcell)
        }.to raise_error StemcellInUse, "Stemcell `test_stemcell/test_version' is still in use by: test-1, test-2"
      end
    end

    context 'when CPI raises an error AND the "force" option is used' do
      it 'should not raise an error' do
        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')

        expect { stemcell_deleter.delete(stemcell, 'force' => true) }.not_to raise_error
      end

      it 'should delete stemcell metadata' do
        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')
        stemcell_deleter.delete(stemcell, 'force' => true)
        expect(Models::Stemcell.all).to be_empty
      end

      it 'should delete associated compiled packages' do
        associated_package = Models::CompiledPackage.make(
          package: Models::Package.make,
          stemcell: stemcell,
          blobstore_id: 'compiled-package-blb-1')

        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')

        expect(blobstore).to receive(:delete).with('compiled-package-blb-1')

        stemcell_deleter.delete(stemcell, 'force' => true)
        expect(Models::CompiledPackage[associated_package.id]).to be_nil
      end
    end

    context 'when stemcell deletion succeeds' do
      let(:stemcell_stage) { instance_double(Bosh::Director::EventLog::Stage) }
      let(:stemcell_metadata_stage) { instance_double(Bosh::Director::EventLog::Stage) }
      let(:compiled_package_stage) { instance_double(Bosh::Director::EventLog::Stage) }

      it 'should delete the stemcell models if the CPI deleted the stemcell' do
        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid')

        stemcell_deleter.delete(stemcell)
        expect(Models::Stemcell.all).to be_empty
      end

      it 'should delete the associated compiled packages' do
        expect(event_log).to receive(:begin_stage).with('Deleting compiled packages', 1, ['test_stemcell', 'test_version']).and_return(compiled_package_stage)
        expect(compiled_package_stage).to receive(:advance_and_track).with('package-name/version').and_yield
        associated_package = Models::CompiledPackage.make(
          package: Models::Package.make(name: 'package-name', version: 'version'),
          stemcell: stemcell,
          blobstore_id: 'compiled-package-blb-1')
        unassociated_package = Models::CompiledPackage.make(
          package: Models::Package.make,
          blobstore_id: 'compiled-package-blb-2')

        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid')

        expect(blobstore).to receive(:delete).with('compiled-package-blb-1')

        stemcell_deleter.delete(stemcell)
        expect(Models::CompiledPackage[associated_package.id]).to be_nil
        expect(Models::CompiledPackage[unassociated_package.id]).not_to be_nil
      end
    end
  end
end
