# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Release do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }
  let(:release_archive) { spec_asset('valid_release.tgz') }
  let(:release_manifest) { spec_asset(File.join('release', 'release.MF')) }
  let(:release_location) { 'http://release_location' }

  before do
    command.stub(:director).and_return(director)
  end
  
  describe 'upload release' do
    it_behaves_like 'a command which requires user is logged in', ->(command) { command.upload('http://release_location') }
      
    context 'when the user is logged in' do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'local release' do
        context 'without rebase' do
          it 'should upload the release manifest' do
            command.should_receive(:upload_manifest).with(release_manifest, {:rebase => nil, :repack => true})
  
            command.upload(release_manifest)
          end          

          it 'should upload the release archive' do
            command.should_receive(:upload_tarball).with(release_archive, {:rebase => nil, :repack => true})
  
            command.upload(release_archive)
          end
        end

        context 'with rebase' do
          it 'should upload the release manifest' do
            command.should_receive(:upload_manifest).with(release_manifest, {:rebase => true, :repack => true})
  
            command.add_option(:rebase, true)
            command.upload(release_manifest)
          end          

          it 'should upload the release archive' do
            command.should_receive(:upload_tarball).with(release_archive, {:rebase => true, :repack => true})
  
            command.add_option(:rebase, true)
            command.upload(release_archive)
          end
        end
      end
      
      context 'remote release' do
        context 'without rebase' do
          it 'should upload the release' do
            command.should_receive(:upload_remote_release)
                .with(release_location, {:rebase => nil, :repack => true}).and_call_original
            director.should_receive(:upload_remote_release).with(release_location)
  
            command.upload(release_location)
          end          
        end
        
        context 'with rebase' do
          it 'should upload the release' do
            command.should_receive(:upload_remote_release)
                .with(release_location, {:rebase => true, :repack => true}).and_call_original
            director.should_receive(:rebase_remote_release).with(release_location)
  
            command.add_option(:rebase, true)
            command.upload(release_location)
          end
        end
      end
    end
  end
end