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

      let(:public_stemcells) do
        instance_double('Bosh::Cli::PublicStemcells')
      end

      before do
        PublicStemcells.stub(:new).and_return(public_stemcells)
        PublicStemcellPresenter.stub(:new).and_return(public_stemcell_presenter)
      end

      it 'lists public stemcells in the index' do
        command.options = double('options')

        command.list_public

        expect(public_stemcell_presenter).to have_received(:list).with(command.options)
      end

      it 'properly wires a stemcell list with a presenter' do
        command.list_public

        expect(PublicStemcellPresenter).to have_received(:new).with(command, public_stemcells)
      end
    end

    describe 'download public stemcell' do
      let(:public_stemcell_presenter) do
        instance_double('Bosh::Cli::PublicStemcellPresenter', download: nil)
      end

      let(:public_stemcells) do
        instance_double('Bosh::Cli::PublicStemcells')
      end

      before do
        PublicStemcells.stub(:new).and_return(public_stemcells)
        PublicStemcellPresenter.stub(:new).and_return(public_stemcell_presenter)
      end

      it 'lists public stemcells in the index' do
        command.download_public('stemcell.tgz')

        expect(public_stemcell_presenter).to have_received(:download).with('stemcell.tgz')
      end

      it 'properly wires a stemcell list with a presenter' do
        command.download_public('stemcell.tgz')

        expect(PublicStemcellPresenter).to have_received(:new).with(command, public_stemcells)
      end
    end

    describe 'list' do
      let(:stemcell1) { { 'name' => 'fake stemcell 1', 'version' => '123', 'cid' => '123456', 'deployments' => [] } }
      let(:stemcell2) { { 'name' => 'fake stemcell 2', 'version' => '456', 'cid' => '789012', 'deployments' => [] } }
      let(:stemcells) { [stemcell1, stemcell2] }
      let(:buffer) { StringIO.new }

      before do
        command.stub(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'

        director.stub(:list_stemcells).and_return(stemcells)
        Bosh::Cli::Config.output = buffer
      end

      it_behaves_like 'a command which requires user is logged in', ->(command) { command.list }

      context 'when no stemcells are in use' do
        it 'does not add a star to any stemcell listed' do
          command.list

          buffer.rewind
          output = buffer.read

          expect(output).to include('| fake stemcell 1 | 123     | 123456 |')
          expect(output).to include('| fake stemcell 2 | 456     | 789012 |')
          expect(output).to include('(*) Currently in-use')
        end
      end

      context 'when there are stemcells in use' do
        let(:stemcell2) { { 'name' => 'fake stemcell 2', 'version' => '456',
                            'cid' => '789012', 'deployments' => ['fake deployment'] } }

        it 'adds a star for stemcells that are in use' do
          command.list

          buffer.rewind
          output = buffer.read

          expect(output).to include('| fake stemcell 1 | 123     | 123456 |')
          expect(output).to include('| fake stemcell 2 | 456*    | 789012 |')
          expect(output).to include('(*) Currently in-use')
        end
      end

      context 'when there are no stemcells' do
        let(:stemcells) { [] }

        it 'errors' do
          expect { command.list }.to raise_error(Bosh::Cli::CliError, 'No stemcells')
        end
      end

      context 'when director does not return deployments for stemcells' do
        let(:stemcell1) { { 'name' => 'fake stemcell 1', 'version' => '123', 'cid' => '123456' } }
        let(:stemcell2) { { 'name' => 'fake stemcell 2', 'version' => '456', 'cid' => '789012' } }

        it 'does not raise' do
          expect { command.list }.to_not raise_error
        end
      end
    end
  end
end
