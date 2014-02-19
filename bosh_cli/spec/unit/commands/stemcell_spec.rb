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
      it_requires_logged_in_user ->(command) { command.upload('http://stemcell_location') }

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
      
      before { stemcell.stub(:validate) }
      before { stemcell.stub(valid?: true) }
      before { stemcell.stub(stemcell_file: stemcell_archive) }

      it_requires_logged_in_user ->(command) { command.list }

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

        context 'when stemcell does not exist' do
          before { director.stub(list_stemcells: []) }

          it 'uploads stemcell and returns successfully' do
            director.should_receive(:upload_stemcell).with(stemcell_archive)
            command.upload(stemcell_archive)
          end
        end

        context 'when stemcell already exists' do
          context 'when the stemcell is local' do
            before { director.stub(list_stemcells: [{'name' => 'ubuntu-stemcell', 'version' => 1}]) }

            context 'when --skip-if-exists flag is given' do
              before { command.add_option(:skip_if_exists, true) }

              it 'does not upload stemcell' do
                director.should_not_receive(:upload_stemcell)
                command.upload(stemcell_archive)
              end

              it 'returns successfully' do
                expect {
                  command.upload(stemcell_archive)
                }.to_not raise_error
              end
            end

            context 'when --skip-if-exists flag is not given' do
              it 'does not upload stemcell' do
                director.should_not_receive(:upload_stemcell)
                command.upload(stemcell_archive) rescue nil
              end

              it 'raises an error' do
                expect {
                  command.upload(stemcell_archive)
                }.to raise_error(Bosh::Cli::CliError, /already exists/)
              end
            end
          end

          context 'when the stemcell is remote' do
            let(:remote_stemcell_location) { 'http://location/stemcell.tgz' }
            let(:task_events_json) { '{"error":{"code":50002}}' }
            before do
              director.stub(:upload_remote_stemcell).with(remote_stemcell_location).and_return([:error, 1])
              director.stub(:get_task_output).with(1, 0, 'event').and_return [task_events_json, nil]
            end

            context 'when --skip-if-exists flag is given' do
              before { command.add_option(:skip_if_exists, true) }

              it 'still uploads stemcell' do
                director.should_receive(:upload_remote_stemcell)
                command.upload(remote_stemcell_location)
              end

              it 'does not raise an error' do
                expect {
                  command.upload(remote_stemcell_location)
                }.to_not raise_error
              end

              it 'has an exit code of 0' do
                command.upload(remote_stemcell_location)
                command.exit_code.should == 0
              end
            end

            context 'when --skip-if-exists flag is not given' do
              it 'still uploads stemcell' do
                director.should_receive(:upload_remote_stemcell)
                command.upload(remote_stemcell_location) rescue nil
              end

              it 'does not raise an error' do
                expect {
                  command.upload(remote_stemcell_location)
                }.to_not raise_error
              end

              it 'has an exit code of 1' do
                command.upload(remote_stemcell_location)
                command.exit_code.should == 1
              end
            end
          end
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
