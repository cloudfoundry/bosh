require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteStemcell do
    describe 'perform' do
      describe 'DJ job class expectations' do
        let(:blobstore) { double('Blobstore') }
        let(:job_type) { :delete_stemcell }
        let(:queue) { :normal }
        it_behaves_like 'a DJ job'
      end

      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      let(:job) { Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore) }

      context 'when the stemcell is known' do
        let!(:stemcell_model) { FactoryBot.create(:models_stemcell, name: 'test_stemcell', version: 'test_version') }
        let(:stemcell_deleter) { instance_double(Jobs::Helpers::StemcellDeleter, delete: nil) }

        before do
          allow(Jobs::Helpers::StemcellDeleter).to receive(:new).and_return(stemcell_deleter)
        end

        it 'deletes the stemcell' do
          expect(stemcell_deleter).to receive(:delete).with(stemcell_model, { blobstore: blobstore })
          job.perform
        end

        context 'when a stemcell_upload is found for some cpi' do
          let!(:match) { FactoryBot.create(:models_stemcell_upload, name: 'test_stemcell', version: 'test_version', cpi: 'cloudy') }
          it 'deletes the stemcell match as well' do
            job.perform
            expect(Models::StemcellUpload.all).to be_empty
          end
        end
      end

      context 'when no stemcell model is found' do
        it 'raises an error' do
          expect { job.perform }.to raise_exception(StemcellNotFound)
        end

        context 'when there are stemcell matches' do
          let!(:match) { FactoryBot.create(:models_stemcell_upload, name: 'test_stemcell', version: 'test_version', cpi: 'cloudy') }
          it 'raises an error but still deletes the stemcell_upload' do
            expect { job.perform }.to raise_exception(StemcellNotFound)

            expect(Models::StemcellUpload.all).to be_empty
          end
        end
      end
    end
  end
end
