require 'spec_helper'

describe Bosh::Cli::Command::Release do
  let(:command) { described_class.new }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }
  let(:release_archive) { spec_asset('valid_release.tgz') }
  let(:release_manifest) { spec_asset(File.join('release', 'release.MF')) }
  let(:release_location) { 'http://release_location' }

  before do
    allow(command).to receive(:director).and_return(director)
  end

  describe 'create release' do
    let(:interactive) { true }
    let(:release) { instance_double('Bosh::Cli::Release') }
    let(:question) { instance_double('HighLine::Question') }

    before do
      allow(command).to receive(:interactive?).and_return(interactive)
      allow(command).to receive(:check_if_release_dir)
      allow(command).to receive(:dirty_blob_check)
      allow(command).to receive(:dirty_state?).and_return(false)
      allow(command).to receive(:version_greater).and_return(false)
      allow(command).to receive(:build_packages).and_return([])
      allow(command).to receive(:build_jobs)
      allow(command).to receive(:build_release)
      allow(command).to receive(:show_summary)
      allow(command).to receive(:release).and_return(release)
      allow(release).to receive(:save_config)
      command.options[:dry_run] = true
    end

    it 'is a command with the correct options' do
      command = Bosh::Cli::Config.commands['create release']
      expect(command).to have_options
      expect(command.options.map(&:first)).to match_array([
        '--force',
        '--final',
        '--with-tarball',
        '--dry-run',
        '--version VERSION',
      ])
    end

    context 'dev release' do
      context 'interactive' do
        let(:interactive) { true }

        context 'when final release name is not set' do
          it 'development release name prompt should not have any default' do
            expect(release).to receive(:dev_name).and_return(nil)
            expect(release).to receive(:final_name).and_return(nil)
            expect(command).to receive(:ask).with('Please enter development release name: ').and_yield(question)
            expect(question).to_not receive(:default=)
            expect(release).to receive(:dev_name=).with('')
            expect(release).to receive(:dev_name).and_return('test-release')

            command.create
          end
        end

        context 'when final release name is set' do
          it 'development release name prompt should default to final release name' do
            expect(release).to receive(:dev_name).and_return(nil)
            expect(release).to receive(:final_name).twice.and_return('test-release')
            expect(command).to receive(:ask).with('Please enter development release name: ').and_yield(question)
            expect(question).to receive(:default=).with('test-release')
            expect(release).to receive(:dev_name=).with('test-release')
            expect(release).to receive(:dev_name).and_return('test-release')

            command.create
          end
        end

        context 'when building a release raises an error' do
          it 'prints the error message' do
            allow(release).to receive(:dev_name).and_return('test-release')

            allow(command).to receive(:build_release).and_raise(Bosh::Cli::ReleaseVersionError.new('the message'))
            allow(command).to receive(:say)
            expect(command).to receive(:say).with('the message')

            command.create
          end
        end
      end

      context 'non-interactive' do
        let(:interactive) { false }

        context 'when final release name is not set' do
          it 'development release name should default to bosh-release' do
            expect(release).to receive(:dev_name).and_return(nil)
            expect(release).to receive(:final_name).and_return(nil)
            expect(release).to receive(:dev_name=).with('bosh-release')

            command.create
          end
        end

        context 'when final release name is set' do
          it 'development release name should be final release name' do
            expect(release).to receive(:dev_name).and_return(nil)
            expect(release).to receive(:final_name).twice.and_return('test')
            expect(release).to receive(:dev_name=).with('test')

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
        allow(command).to receive(:logged_in?).and_return(true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'local release' do
        context 'without rebase' do
          it 'should upload the release manifest' do
            expect(command).to receive(:upload_manifest)
              .with(release_manifest, hash_including(:rebase => nil))
            command.upload(release_manifest)
          end

          it 'should upload the release archive' do
            expect(command).to receive(:upload_tarball)
              .with(release_archive, hash_including(:rebase => nil))
            command.upload(release_archive)
          end
        end

        context 'with rebase' do
          it 'should upload the release manifest' do
            expect(command).to receive(:upload_manifest)
              .with(release_manifest, hash_including(:rebase => true))
            command.add_option(:rebase, true)
            command.upload(release_manifest)
          end

          it 'should upload the release archive' do
            expect(command).to receive(:upload_tarball)
              .with(release_archive, hash_including(:rebase => true))
            command.add_option(:rebase, true)
            command.upload(release_archive)
          end
        end

        context 'when release does not exist' do
          before { allow(director).to receive(:match_packages).and_return([]) }
          before { allow(director).to receive(:get_release).and_raise(Bosh::Cli::ResourceNotFound) }
          let(:tarball_path) { spec_asset('valid_release.tgz') }

          it 'uploads release and returns successfully' do
            expect(director).to receive(:upload_release).with(tarball_path)
            command.upload(tarball_path)
          end
        end

        context 'when release already exists' do
          before { allow(director).to receive(:match_packages).and_return([]) }
          before { allow(director).to receive(:get_release).and_return(
            {'jobs' => nil, 'packages' => nil, 'versions' => ['0.1']}) }
          let(:tarball_path) { spec_asset('valid_release.tgz') }

          context 'when --skip-if-exists flag is given' do
            before { command.add_option(:skip_if_exists, true) }

            it 'does not upload release' do
              expect(director).to_not receive(:upload_release)
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
              expect(director).to_not receive(:upload_release)
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
            expect(command).to receive(:upload_remote_release)
              .with(release_location, hash_including(:rebase => nil))
              .and_call_original
            expect(director).to receive(:upload_remote_release).with(release_location)

            command.upload(release_location)
          end
        end

        context 'with rebase' do
          it 'should upload the release' do
            expect(command).to receive(:upload_remote_release)
              .with(release_location, hash_including(:rebase => true))
              .and_call_original
            expect(director).to receive(:rebase_remote_release).with(release_location)

            command.add_option(:rebase, true)
            command.upload(release_location)
          end
        end
      end
    end
  end
end
