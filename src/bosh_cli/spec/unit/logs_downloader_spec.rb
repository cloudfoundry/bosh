require 'spec_helper'

describe Bosh::Cli::LogsDownloader do
  subject { described_class.new(director, ui) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }
  let(:ui) { instance_double('Bosh::Cli::Command::Base', say: nil, err: nil, nl: nil) }

  describe '#build_destination_path' do
    before { Timecop.freeze(Time.new(2011, 10, 9, 11, 55, 45)) }
    after { Timecop.return }

    it 'returns timestamped tgz file name in given directory' do
      path = subject.build_destination_path('fake-job-name', 'fake-job-index', '/fake-dir')
      expect(path).to eq('/fake-dir/fake-job-name.fake-job-index.2011-10-09-11-55-45.tgz')
    end
  end

  describe '#download' do
    def perform
      subject.download('fake-blobstore-id', '/fake-final-path')
    end

    before { allow(FileUtils).to receive(:mv) }

    it 'downloads resource for given blobstore id' do
      expect(director).to receive(:download_resource).
        with('fake-blobstore-id').
        and_return('/fake-tmp-path')

      perform
    end

    context 'when downloading resource succeeds' do
      before { allow(director).to receive(:download_resource).and_return('/fake-tmp-path') }

      it 'says downloading succeeded and includes final logs destination path' do
        expect(ui).to receive(:say).with("Downloading log bundle (fake-blobstore-id)...")
        expect(ui).to receive(:say).with("Logs saved in '/fake-final-path'")
        perform
      end

      it 'moves tmp file to final logs destination path' do
        expect(FileUtils).to receive(:mv).with('/fake-tmp-path', '/fake-final-path')
        perform
      end

      it 'cleans up tmp files when moving tmp file to final destination fails' do
        expect(FileUtils).to receive(:mv).and_raise(Exception)
        expect(FileUtils).to receive(:rm_rf).with('/fake-tmp-path')
        expect { perform }.to raise_error
      end
    end

    context 'when downloading resource fails' do
      before { allow(director).to receive(:download_resource).and_raise(error) }
      let(:error) { Bosh::Cli::DirectorError.new('fake-error') }

      it 'says downloading failed in the ui' do
        expect(ui).to receive(:say).with("Downloading log bundle (fake-blobstore-id)...")
        expect(ui).to receive(:err).with("Unable to download logs from director: #{error}")
        perform
      end
    end
  end
end
