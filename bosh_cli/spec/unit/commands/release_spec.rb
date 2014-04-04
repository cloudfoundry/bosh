# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Release do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:release_archive) { spec_asset('valid_release.tgz') }
  let(:release_manifest) { spec_asset(File.join('release', 'release.MF')) }
  let(:release_location) { 'http://release_location' }

  before do
    command.stub(:director).and_return(director)
  end

  describe 'create release' do
    let(:release) { double('Bosh::Cli::Release', :min_cli_version => '1') }
    let(:question) { double('HighLine::Question') }

    before do
      command.stub(:interactive?).and_return(interactive)
      command.stub(:check_if_release_dir)
      command.stub(:dirty_blob_check)
      command.stub(:dirty_state?).and_return(false)
      command.stub(:version_greater).and_return(false)
      command.stub(:build_packages).and_return([])
      command.stub(:build_jobs)
      command.stub(:build_release)
      command.stub(:show_summary)
      command.stub(:release).and_return(release)
      release.stub(:save_config)
      command.options[:dry_run] = true
    end

    context 'dev release' do
      context 'interactive' do
        let(:interactive) { true }

        context 'when final release name is not set' do
          it 'development release name prompt should not have any default' do
            release.should_receive(:dev_name).and_return(nil)
            release.should_receive(:final_name).and_return(nil)
            command.should_receive(:ask).with("Please enter development release name: ").and_yield(question)
            question.should_not_receive(:default=)
            release.should_receive(:dev_name=).with('')
            release.should_receive(:dev_name).and_return('test-release')

            command.create
          end
        end

        context 'when final release name is set' do
          it 'development release name prompt should default to final release name' do
            release.should_receive(:dev_name).and_return(nil)
            release.should_receive(:final_name).twice.and_return('test-release')
            command.should_receive(:ask).with("Please enter development release name: ").and_yield(question)
            question.should_receive(:default=).with('test-release')
            release.should_receive(:dev_name=).with('test-release')
            release.should_receive(:dev_name).and_return('test-release')

            command.create
          end
        end
      end

      context 'non-interactive' do
        let(:interactive) { false }

        context 'when final release name is not set' do
          it 'development release name should default to bosh-release' do
            release.should_receive(:dev_name).and_return(nil)
            release.should_receive(:final_name).and_return(nil)
            release.should_receive(:dev_name=).with('bosh-release')

            command.create
          end
        end

        context 'when final release name is set' do
          it 'development release name should be final release name' do
            release.should_receive(:dev_name).and_return(nil)
            release.should_receive(:final_name).twice.and_return('test')
            release.should_receive(:dev_name=).with('test')

            command.create
          end
        end
      end
    end
  end
  

  describe 'upload release' do
    it_requires_logged_in_user ->(command) { command.upload('http://release_location') }

    context 'when the user is logged in' do
      before do
        command.stub(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'local release' do
        context 'without rebase' do
          it 'should upload the release manifest' do
            command.should_receive(:upload_manifest)
              .with(release_manifest, hash_including(:rebase => nil))
            command.upload(release_manifest)
          end

          it 'should upload the release archive' do
            command.should_receive(:upload_tarball)
              .with(release_archive, hash_including(:rebase => nil))
            command.upload(release_archive)
          end
        end

        context 'with rebase' do
          it 'should upload the release manifest' do
            command.should_receive(:upload_manifest)
              .with(release_manifest, hash_including(:rebase => true))
            command.add_option(:rebase, true)
            command.upload(release_manifest)
          end

          it 'should upload the release archive' do
            command.should_receive(:upload_tarball)
              .with(release_archive, hash_including(:rebase => true))
            command.add_option(:rebase, true)
            command.upload(release_archive)
          end
        end

        context 'when release does not exist' do
          before { director.stub(match_packages: []) }
          before { director.stub(:get_release).and_raise(Bosh::Cli::ResourceNotFound) }
          let(:tarball_path) { spec_asset('valid_release.tgz') }

          it 'uploads release and returns successfully' do
            director.should_receive(:upload_release).with(tarball_path)
            command.upload(tarball_path)
          end
        end

        context 'when release already exists' do
          before { director.stub(match_packages: []) }
          before { director.stub(get_release:
            {'jobs' => nil, 'packages' => nil, 'versions' => ['0.1']}) }
          let(:tarball_path) { spec_asset('valid_release.tgz') }

          context 'when --skip-if-exists flag is given' do
            before { command.add_option(:skip_if_exists, true) }

            it 'does not upload release' do
              director.should_not_receive(:upload_release)
              command.upload(tarball_path)
            end

            it 'returns successfully' do
              expect {
                command.upload(tarball_path)
              }.to_not raise_error
            end
          end

          context 'when --skip-if-exists flag is not given' do
            it 'does not upload release' do
              director.should_not_receive(:upload_release)
              command.upload(tarball_path) rescue nil
            end

            it 'raises an error' do
              expect {
                command.upload(tarball_path)
              }.to raise_error(Bosh::Cli::CliError, /already been uploaded/)
            end
          end
        end
      end

      context 'remote release' do
        context 'without rebase' do
          it 'should upload the release' do
            command.should_receive(:upload_remote_release)
              .with(release_location, hash_including(:rebase => nil))
              .and_call_original
            director.should_receive(:upload_remote_release).with(release_location)

            command.upload(release_location)
          end
        end

        context 'with rebase' do
          it 'should upload the release' do
            command.should_receive(:upload_remote_release)
              .with(release_location, hash_including(:rebase => true))
              .and_call_original
            director.should_receive(:rebase_remote_release).with(release_location)

            command.add_option(:rebase, true)
            command.upload(release_location)
          end
        end
      end
    end
  end
end
