require 'spec_helper'
require 'cli/public_stemcell_presenter'
require 'cli/public_stemcells'

module Bosh::Cli
  describe PublicStemcellPresenter do
    let(:ui) do
      ui = instance_double('Bosh::Cli::Command::Base', say: nil, confirmed?: true)
      allow(ui).to receive(:err) { raise 'err would have normally raised interrupting control flow' }
      ui
    end

    let(:download_with_progress) do
      instance_double('Bosh::Cli::DownloadWithProgress', perform: nil, sha1?: true, sha1: 'download-sha1')
    end

    let(:recent_stemcell) do
      PublicStemcell.new('foobar-456.tgz', 1111111)
    end

    let(:older_stemcell) do
      PublicStemcell.new('foobar-123.tgz', 2222222)
    end

    let(:public_stemcell_index) do
      stemcells = PublicStemcells.new
      allow(stemcells).to receive_messages(all: [recent_stemcell, older_stemcell])
      stemcells
    end

    subject(:public_stemcell_presenter) do
      PublicStemcellPresenter.new(ui, public_stemcell_index)
    end

    before do
      allow(DownloadWithProgress).to receive(:new).and_return(download_with_progress)
    end

    describe '#list' do
      it 'provides a hint describing how to download a public stemcell' do
        public_stemcell_presenter.list({})

        expect(ui).to have_received(:say).with(/To download use/)
      end

      context 'by default' do
        it 'only lists a table of most recent public stemcells' do
          public_stemcell_presenter.list({})

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+----------------+
| Name           |
+----------------+
| foobar-456.tgz |
+----------------+
          TABLE
        end
      end

      context 'when :all is specified' do
        it 'lists  a table of all public stemcells' do
          public_stemcell_presenter.list(all: true)

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+----------------+
| Name           |
+----------------+
| foobar-456.tgz |
| foobar-123.tgz |
+----------------+
          TABLE
        end
      end

      context 'when :full is specified' do
        it 'adds a column with the url to each public stemcell' do
          public_stemcell_presenter.list(full: true)

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+----------------+----------------------------------------------------------------+
| Name           | Url                                                            |
+----------------+----------------------------------------------------------------+
| foobar-456.tgz | https://bosh-jenkins-artifacts.s3.amazonaws.com/foobar-456.tgz |
+----------------+----------------------------------------------------------------+
          TABLE
        end
      end
    end

    describe '#download' do
      it 'downloads a stemcell from the public stemcell index, reporting progress along the way' do
        public_stemcell_presenter.download('foobar-456.tgz')

        expect(DownloadWithProgress).to have_received(:new).with('https://bosh-jenkins-artifacts.s3.amazonaws.com/foobar-456.tgz', recent_stemcell.size)
        expect(download_with_progress).to have_received(:perform)
      end

      it 'reports success' do
        public_stemcell_presenter.download('foobar-456.tgz')

        expect(ui).to have_received(:say).with(/Download complete/)
      end

      context 'when the specified stemcell is not in the index' do
        it 'reports an error' do
          expect {
            public_stemcell_presenter.download('missing-123.tgz')
          }.to raise_error

          expect(ui).to have_received(:err).with(/'missing-123.tgz' not found/)
        end
      end

      context 'when the specified stemcell has been previously downloaded' do
        before do
          allow(File).to receive(:exists?).with('foobar-456.tgz').and_return(true)
        end

        it 'confirms the user wishes to overwrite the existing file' do
          public_stemcell_presenter.download('foobar-456.tgz')

          expect(ui).to have_received(:confirmed?).with(/Overwrite existing file/)
        end
      end
    end
  end
end
