# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Stemcell do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }
  let(:stemcell_archive) { spec_asset("valid_stemcell.tgz") }
  let(:stemcell_manifest) { {'name' => 'ubuntu-stemcell', 'version' => 1} }
  let(:stemcell) { mock('stemcell', :manifest => stemcell_manifest) }
  let(:cache) { mock('cache') }

  before do
    command.stub(:director).and_return(director)
    Bosh::Cli::Stemcell.stub(:new).and_return(stemcell)
    Bosh::Cli::Config.cache = cache
  end
  
  describe 'upload stemcell' do
    it_behaves_like 'a command which requires user is logged in', ->(command) { command.upload('http://stemcell_location') }
      
    context 'when the user is logged in' do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
        cache.stub(:read).and_return(nil)
        cache.stub(:write)
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
end