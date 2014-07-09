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

    describe '#create_stemcell_from_stream' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('fake-uuid')
        allow(File).to receive(:exists?).and_return(true)
      end

      let(:stemcell_stream) { double('fake-stemcell-stream', size: 1024) }

      it 'enqueues a task to upload a local stemcell' do
        expect(subject).to receive(:check_available_disk_space).
          with(anything, stemcell_stream.size).
          and_return(true)

        tmp_file_path = File.join(Dir.tmpdir, 'stemcell-fake-uuid')
        expect(subject).to receive(:write_file).with(tmp_file_path, stemcell_stream)

        expect(job_queue).to receive(:enqueue).with(
          username,
          Jobs::UpdateStemcell,
          'create stemcell',
          [tmp_file_path],
        ).and_return(task)

        expect(subject.create_stemcell_from_stream(username, stemcell_stream)).to eql(task)
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
  end
end
