require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::StemcellDeleter do
    let(:blobstore) { instance_double(Bosh::Director::Blobstore::BaseClient) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
    let(:stemcell_deleter) { Jobs::Helpers::StemcellDeleter.new(per_spec_logger) }
    let(:stemcell) { FactoryBot.create(:models_stemcell, name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid') }

    before do
      fake_locks
      allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud_factory).to receive(:get).with('').and_return(cloud)
    end

    context 'when stemcell deletion fails' do
      it "should raise error if CPI can't delete the stemcell" do
        expect(cloud).to receive(:delete_stemcell).with('stemcell_cid').and_raise('error')

        expect {
          stemcell_deleter.delete(stemcell)
        }.to raise_error(/error/)
      end

      it 'should raise error if the deployments still reference this stemcell' do
        deployment_1 = FactoryBot.create(:models_deployment, name: 'test-1')
        deployment_1.add_stemcell(stemcell)
        deployment_2 = FactoryBot.create(:models_deployment, name: 'test-2')
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
        associated_package = FactoryBot.create(:models_compiled_package,
          package: FactoryBot.create(:models_package),
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
        associated_package = FactoryBot.create(:models_compiled_package,
          package: FactoryBot.create(:models_package, name: 'package-name', version: 'version'),
          blobstore_id: 'compiled-package-blb-1',
          stemcell_os: 'AIX',
          stemcell_version: '7.1'
        )
        unassociated_package = FactoryBot.create(:models_compiled_package,
          package: FactoryBot.create(:models_package),
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

    describe 'looking up clouds for a stemcell' do
      let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
      before {
        allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      }

      context 'if no cpi is set on stemcell' do
        let(:stemcell) { FactoryBot.create(:models_stemcell, name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid', cpi: '') }

        it 'calls the default cloud' do
          cloud = instance_double(Bosh::Clouds::ExternalCpi)
          expect(cloud_factory).to receive(:get).with('').and_return(cloud)
          expect(cloud).to receive(:delete_stemcell)
          stemcell_deleter.delete(stemcell)
        end
      end

      context 'if a certain cpi is set on a stemcell' do
        let(:stemcell) { FactoryBot.create(:models_stemcell, name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid', cpi: 'cpi1') }

        it 'calls the cloud that cloud factory returns' do
          cloud = instance_double(Bosh::Clouds::ExternalCpi)
          expect(cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
          expect(cloud).to receive(:delete_stemcell)
          stemcell_deleter.delete(stemcell)
        end

        it 'fails if cloud factory does not return a cloud for the cpi' do
          expect(cloud_factory).to receive(:get).with('cpi1').and_return(nil)
          expect{
            stemcell_deleter.delete(stemcell)
          }.to raise_error /Stemcell has CPI defined \(cpi1\) that is not configured anymore./
        end
      end
    end
  end
end
