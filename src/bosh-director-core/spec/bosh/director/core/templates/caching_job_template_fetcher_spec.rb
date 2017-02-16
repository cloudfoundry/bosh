require 'spec_helper'

require 'bosh/director/core/templates/caching_job_template_fetcher'

module Bosh::Director::Core::Templates
  describe CachingJobTemplateFetcher do
    let(:job_template) { double('Bosh::Director::DeploymentPlan::Job', download_blob: '/template1', blobstore_id: 'blob-id') }
    let(:job_template2) { double('Bosh::Director::DeploymentPlan::Job', download_blob: '/template2', blobstore_id: 'blob-id2') }

    describe '#download_blob' do
      context 'when the blob has not been downloaded' do
        it 'should download the blob' do
          expect(subject.download_blob(job_template)).to eq('/template1')
          expect(job_template).to have_received(:download_blob)
        end
      end

      context 'when the blob has already been downloaded' do
        it 'should not re-download the blob' do
          expect(subject.download_blob(job_template)).to eq('/template1')
          expect(subject.download_blob(job_template)).to eq('/template1')

          expect(job_template).to have_received(:download_blob).once
        end
      end
    end

    describe '#clean' do
      before do
        subject.download_blob(job_template)
        subject.download_blob(job_template2)
      end

      it 'removes all the files that got downloaded' do
        expect(FileUtils).to receive(:rm_f).with('/template1')
        expect(FileUtils).to receive(:rm_f).with('/template2')

        subject.clean_cache!
      end
    end
  end
end
