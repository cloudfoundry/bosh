require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteStemcell do
    describe 'perform' do
      describe 'Resque job class expectations' do
        let(:job_type) { :delete_stemcell }
        it_behaves_like 'a Resque job'
      end

      it 'should fail for unknown stemcells' do
        allow(Config).to receive(:cloud).and_return(instance_double(Bosh::Cloud))
        blobstore = instance_double(Bosh::Blobstore::BaseClient)

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)

        expect { job.perform }.to raise_exception(StemcellNotFound)
      end
    end
  end
end
