require 'spec_helper'

module Bosh::Cli
  describe Command::Stemcell do
    let(:director) { double(Bosh::Cli::Client::Director) }
    let(:stemcell_archive) { spec_asset("valid_stemcell.tgz") }
    let(:stemcell_manifest) { {'name' => 'ubuntu-stemcell', 'version' => 1} }
    let(:stemcell) { double('stemcell', :manifest => stemcell_manifest) }

    subject(:command) do
      Bosh::Cli::Command::Stemcell.new
    end

    before do
      command.stub(:director).and_return(director)
      Bosh::Cli::Stemcell.stub(:new).and_return(stemcell)
    end

    describe 'upload stemcell' do
      it_behaves_like 'a command which requires user is logged in', ->(command) { command.upload('http://stemcell_location') }

      context 'when the user is logged in' do
        before do
          command.stub(:logged_in? => true)
          command.options[:target] = 'http://bosh-target.example.com'
        end

        context 'local stemcell' do
          it 'should upload the stemcell' do
            stemcell.should_receive(:validate)
            stemcell.should_receive(:valid?).and_return(true)
            director.should_receive(:list_stemcells).and_return([])
            stemcell.should_receive(:stemcell_file).and_return(stemcell_archive)
            director.should_receive(:upload_stemcell).with(stemcell_archive)

            command.upload(stemcell_archive)
          end

          it 'should not upload the stemcell if is invalid' do
            stemcell.should_receive(:validate)
            stemcell.should_receive(:valid?).and_return(false)
            director.should_not_receive(:upload_stemcell)

            expect {
              command.upload(stemcell_archive)
            }.to raise_error(Bosh::Cli::CliError, /Stemcell is invalid/)
          end

          it 'should not upload the stemcell if already exist' do
            stemcell.should_receive(:validate)
            stemcell.should_receive(:valid?).and_return(true)
            director.should_receive(:list_stemcells).and_return([stemcell_manifest])
            director.should_not_receive(:upload_stemcell)

            expect {
              command.upload(stemcell_archive)
            }.to raise_error(Bosh::Cli::CliError, /already exists/)
          end
        end

        context 'remote stemcell' do
          it 'should upload the stemcell' do
            director.should_receive(:upload_remote_stemcell).with('http://stemcell_location')

            command.upload('http://stemcell_location')
          end
        end
      end
    end

    describe 'public stemcells' do
      let(:public_stemcell_presenter) do
        instance_double('Bosh::Cli::PublicStemcellPresenter', list: nil)
      end

      let(:public_stemcell_index) do
        instance_double('Bosh::Cli::PublicStemcellIndex')
      end

      before do
        PublicStemcellIndex.stub(:download).and_return(public_stemcell_index)
        PublicStemcellPresenter.stub(:new).and_return(public_stemcell_presenter)
      end

      it 'lists public stemcells in the index' do
        command.options = double('options')

        command.list_public

        expect(public_stemcell_presenter).to have_received(:list).with(command.options)
      end

      it 'properly wires a stemcell index with a presenter' do
        command.list_public

        expect(PublicStemcellIndex).to have_received(:download).with(command)
        expect(PublicStemcellPresenter).to have_received(:new).with(command, public_stemcell_index)
      end
    end

    describe 'download public stemcell' do
      let(:public_stemcell_presenter) do
        instance_double('Bosh::Cli::PublicStemcellPresenter', download: nil)
      end

      let(:public_stemcell_index) do
        instance_double('Bosh::Cli::PublicStemcellIndex')
      end

      before do
        PublicStemcellIndex.stub(:download).and_return(public_stemcell_index)
        PublicStemcellPresenter.stub(:new).and_return(public_stemcell_presenter)
      end

      it 'lists public stemcells in the index' do
        command.download_public('stemcell.tgz')

        expect(public_stemcell_presenter).to have_received(:download).with('stemcell.tgz')
      end

      it 'properly wires a stemcell index with a presenter' do
        command.download_public('stemcell.tgz')

        expect(PublicStemcellIndex).to have_received(:download).with(command)
        expect(PublicStemcellPresenter).to have_received(:new).with(command, public_stemcell_index)
      end
    end
  end
end
