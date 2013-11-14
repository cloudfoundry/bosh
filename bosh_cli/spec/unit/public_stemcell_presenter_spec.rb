require 'spec_helper'
require 'cli/public_stemcell_presenter'

module Bosh::Cli
  describe PublicStemcellPresenter do
    let(:ui) do
      ui = instance_double('Bosh::Cli::Command::Base', say: nil, confirmed?: true)
      ui.stub(:err) { raise 'err would have normally raised interrupting control flow' }
      ui
    end

    let(:download_with_progress) do
      instance_double('Bosh::Cli::DownloadWithProgress', perform: nil, sha1?: true, sha1: 'download-sha1')
    end

    let(:public_stemcell_index) do
      PublicStemcellIndex.new(
        'stable.tgz' => {
          'url' => 'http://example.com/stable.tgz',
          'size' => 123,
          'tags' => %w[stable]
        },

        'foobar.tgz' => {
          'url' => 'http://example.com/foobar.tgz',
          'size' => 456,
          'tags' => %w[foo bar]
        }
      )
    end

    subject(:public_stemcell_presenter) do
      PublicStemcellPresenter.new(ui)
    end

    before do
      DownloadWithProgress.stub(:new).and_return(download_with_progress)
      PublicStemcellIndex.stub(:download).with(ui).and_return(public_stemcell_index)
      PublicStemcell.any_instance.stub(sha1: 'stemcell-sha1')
    end

    describe '#list' do
      it 'provides a hint describing how to download a public stemcell' do
        public_stemcell_presenter.list({})

        expect(ui).to have_received(:say).with(/To download use/)
      end

      context 'by default' do
        it 'only lists a table of public stemcells tagged "stable"' do
          public_stemcell_presenter.list({})

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+------------+--------+
| Name       | Tags   |
+------------+--------+
| stable.tgz | stable |
+------------+--------+
          TABLE
        end
      end

      context 'when :tags are specified' do
        it 'only lists a table of public stemcells matching all specified tags' do
          public_stemcell_presenter.list(tags: %w(foo))

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+------------+----------+
| Name       | Tags     |
+------------+----------+
| foobar.tgz | foo, bar |
+------------+----------+
          TABLE
        end
      end

      context 'when :all is specified' do
        it 'lists  a table of all public stemcells, even those not tagged "stable"' do
          public_stemcell_presenter.list(all: true)

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+------------+----------+
| Name       | Tags     |
+------------+----------+
| foobar.tgz | foo, bar |
| stable.tgz | stable   |
+------------+----------+
          TABLE
        end
      end

      context 'when :full is specified' do
        it 'adds a column with the url to each public stemcell' do
          public_stemcell_presenter.list(full: true)

          expect(ui).to have_received(:say).with(<<-TABLE.strip)
+------------+-------------------------------+--------+
| Name       | Url                           | Tags   |
+------------+-------------------------------+--------+
| stable.tgz | http://example.com/stable.tgz | stable |
+------------+-------------------------------+--------+
          TABLE
        end
      end
    end

    describe '#download' do
      it 'downloads a stemcell from the public stemcell index, reporting progress along the way' do
        public_stemcell_presenter.download('stable.tgz')

        expect(DownloadWithProgress).to have_received(:new).with(123, 'http://example.com/stable.tgz')
        expect(download_with_progress).to have_received(:perform)
      end

      context 'when the specified stemcell is not in the index' do
        it 'reports an error' do
          expect {
            public_stemcell_presenter.download('missing.tgz')
          }.to raise_error

          expect(ui).to have_received(:err).with(/'missing.tgz' not found/)
        end
      end

      context 'when the specified stemcell has been previously downloaded' do
        before do
          File.stub(:exists?).with('stable.tgz').and_return(true)
        end

        it 'confirms the user wishes to overwrite the existing file' do
          public_stemcell_presenter.download('stable.tgz')

          expect(ui).to have_received(:confirmed?).with(/Overwrite existing file/)
        end
      end

      context 'when the sha1 of the downloaded stemcell matches the sha1 in the index' do
        it 'reports success' do
          public_stemcell_presenter.download('stable.tgz')

          expect(ui).to have_received(:say).with(/Download complete/)
        end
      end

      context 'when the sha1 of the downloaded stemcell does not match the sha1 in the index' do
        before do
          download_with_progress.stub(sha1?: false)
        end

        it 'reports an error' do
          expect {
            public_stemcell_presenter.download('stable.tgz')
          }.to raise_error

          expect(ui).to have_received(:err).with(/does not match the expected sha1/)
        end
      end
    end
  end
end
