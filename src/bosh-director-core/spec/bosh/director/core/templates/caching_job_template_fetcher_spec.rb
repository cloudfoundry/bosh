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

        it 'should be thread safe' do
          subject # ensure this has been initiated before we launch threads
          allow(job_template).to receive(:download_blob) { Thread.pass; '/template1' }

          t1 = Thread.new { expect(subject.download_blob(job_template)).to eq('/template1') }
          t2 = Thread.new { expect(subject.download_blob(job_template)).to eq('/template1') }

          t1.join
          t2.join

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

      it 'clears its internal cache list' do
        subject.download_blob(job_template)
        subject.clean_cache!
        subject.download_blob(job_template)
        expect(job_template).to have_received(:download_blob).twice
        end
    end
  end
end
