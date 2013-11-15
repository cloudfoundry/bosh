require 'spec_helper'
require 'cli/public_stemcell_index'

module Bosh::Cli
  describe PublicStemcellIndex do
    let(:index) do
      {
        'foo-stemcell.tgz' => {'sha1' => 'foo-sha1'},
        'bar-stemcell.tgz' => {'sha1' => 'bar-sha1'},
      }
    end

    subject(:public_stemcell_index) do
      Bosh::Cli::PublicStemcellIndex.new(index)
    end

    describe '.download' do
      let(:ui) { instance_double('Bosh::Cli::Command', err: nil) }

      let(:status_code) do
        HTTP::Status::OK
      end

      let(:response) do
        instance_double('HTTP::Message',
             body: index.to_yaml,
             http_header: instance_double('HTTP::Message::Headers', status_code: status_code))
      end

      let(:http_client) do
        instance_double('HTTPClient', get: response)
      end

      before do
        PublicStemcellIndex.stub(new: public_stemcell_index)
        HTTPClient.stub(new: http_client)
      end

      it 'downloads the public stemcell index yaml and creates a PublicStemcellIndex using this' do
        download = PublicStemcellIndex.download(ui)

        expect(download).to eq(public_stemcell_index)
        expect(http_client).to have_received(:get).with('https://s3.amazonaws.com/blob.cfblob.com/stemcells/public_stemcells_index.yml')
        expect(PublicStemcellIndex).to have_received(:new).with(index)
      end

      context 'when the download fails' do
        let(:status_code) do
          HTTP::Status::INTERNAL
        end

        it 'reports the error' do
          PublicStemcellIndex.download(ui)

          expect(ui).to have_received(:err).with(%r{Received HTTP 500 from.*public_stemcells_index.yml})
        end
      end
    end

    describe '#has_stemcell?' do
      it { should have_stemcell('foo-stemcell.tgz') }
      it { should_not have_stemcell('baz-stemcell.tgz') }
    end

    describe '#names' do
      it 'sorts alphabetically' do
        expect(public_stemcell_index.names).to eq(%w(bar-stemcell.tgz foo-stemcell.tgz))
      end
    end

    describe '#find' do
      it 'returns a PublicStemcell corresponding to the specified name' do
        public_stemcell = public_stemcell_index.find('foo-stemcell.tgz')

        expect(public_stemcell).to be_a(PublicStemcell)
        expect(public_stemcell.name).to eq('foo-stemcell.tgz')
        expect(public_stemcell.sha1).to eq('foo-sha1')
      end
    end

    describe '#each' do
      it 'yields a PublicStemcell for each key in the index' do
        public_stemcells = []
        public_stemcell_index.each do |public_stemcell|
          public_stemcells << public_stemcell
        end

        expect(public_stemcells).to have(2).stemcells
        expect(public_stemcells.map(&:name)).to eq(%w(bar-stemcell.tgz foo-stemcell.tgz))
      end
    end
  end
end
