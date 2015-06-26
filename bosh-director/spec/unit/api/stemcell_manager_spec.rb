require 'spec_helper'

module Bosh::Director
  describe Api::StemcellManager do
    let(:username) { 'fake-username' }
    let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    describe '#create_stemcell_from_url' do
      let(:stemcell_url) { 'http://fake-domain.com/stemcell.tgz' }

      it 'enqueues a task to upload a remote stemcell' do
        expect(job_queue).to receive(:enqueue).with(
          username,
          Jobs::UpdateStemcell,
          'create stemcell',
          [stemcell_url, { remote: true }],
        ).and_return(task)

        expect(subject.create_stemcell_from_url(username, stemcell_url)).to eql(task)
      end
    end

    describe '#create_stemcell_from_file_path' do
      let(:stemcell_path) { '/path/to/stemcell.tgz' }

      context 'when stemcell file exists' do
        before { allow(File).to receive(:exists?).with(stemcell_path).and_return(true) }

        it 'enqueues a task to upload a remote stemcell' do
          expect(job_queue).to receive(:enqueue).with(
            username,
            Jobs::UpdateStemcell,
            'create stemcell',
            [stemcell_path],
          ).and_return(task)

          expect(subject.create_stemcell_from_file_path(username, stemcell_path)).to eql(task)
        end
      end

      context 'when stemcell file does not exist' do
        before { allow(File).to receive(:exists?).with(stemcell_path).and_return(false) }

        it 'raises an error' do
          expect(job_queue).to_not receive(:enqueue)

          expect {
            expect(subject.create_stemcell_from_file_path(username, stemcell_path))
          }.to raise_error(DirectorError, /Failed to create stemcell: file not found/)
        end
      end
    end

    describe '#find_by_os_and_version' do
      before {
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-a',
        )
      }

      it 'raises an error when the requested stemcell is not found' do
        expect {
          subject.find_by_os_and_version('CBM BASIC V2', '1')
        }.to raise_error(Bosh::Director::StemcellNotFound)
      end

      it 'returns the uniquely matching stemcell' do
        stemcell = subject.find_by_os_and_version('stemcell_os', 'stemcell_version')
        expect(stemcell.name).to eq('my-stemcell-with-a-name')
      end

      context 'when there are multiple matches for the requested OS and version' do
        before {
          Bosh::Director::Models::Stemcell.create(
              name: 'my-stemcell-with-b-name',
              version: 'stemcell_version',
              operating_system: 'stemcell_os',
              cid: 'cloud-id-b',
          )
        }

        it 'chooses the first stemcell alhpabetically by name' do
          stemcell = subject.find_by_os_and_version('stemcell_os', 'stemcell_version')
          expect(stemcell.name).to eq('my-stemcell-with-a-name')
        end
      end
    end
  end
end
