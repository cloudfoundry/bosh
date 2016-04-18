require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::StemcellDeleter do
    let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
    let(:blob_deleter) { Jobs::Helpers::BlobDeleter.new(blobstore, logger) }
    let(:cloud) { instance_double(Bosh::Cloud) }
    let(:package_deleter) { Jobs::Helpers::CompiledPackageDeleter.new(blob_deleter, logger)}
    let(:stemcell_deleter) { Jobs::Helpers::StemcellDeleter.new(cloud, package_deleter, logger) }
    let(:stemcell) { Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid') }

    before do
      fake_locks
      allow(Config).to receive(:cloud).and_return(cloud)
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
        }.to raise_error StemcellInUse, "Stemcell 'test_stemcell/test_version' is still in use by: test-1, test-2"
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

      it 'should NOT delete associated compiled packages, but set stemcell_id to nil' do
        associated_package = Models::CompiledPackage.make(
          package: Models::Package.make,
          blobstore_id: 'compiled-package-blb-1',
          stemcell_os: 'Plan 9',
          stemcell_version: '9'
        )

        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')

        expect(blobstore).not_to receive(:delete).with('compiled-package-blb-1')

        stemcell_deleter.delete(stemcell, 'force' => true)

        expect(Models::CompiledPackage[associated_package.id]).to eq(associated_package)
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

      it 'should NOT delete the associated compiled packages, but set stemcell_id to nil' do
        associated_package = Models::CompiledPackage.make(
          package: Models::Package.make(name: 'package-name', version: 'version'),
          blobstore_id: 'compiled-package-blb-1',
          stemcell_os: 'AIX',
          stemcell_version: '7.1'
        )
        unassociated_package = Models::CompiledPackage.make(
          package: Models::Package.make,
          blobstore_id: 'compiled-package-blb-2',
          stemcell_os: 'AIX',
          stemcell_version: '7.2'
        )

        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid')

        expect(blobstore).not_to receive(:delete).with('compiled-package-blb-1')

        stemcell_deleter.delete(stemcell)

        expect(Models::CompiledPackage[associated_package.id]).to eq(associated_package)
        expect(Models::CompiledPackage[unassociated_package.id]).to eq(unassociated_package)
      end
    end
  end
end
