require 'spec_helper'

describe Bosh::Cli::Command::Release do
  subject(:command) { described_class.new }

  let(:director) do
    instance_double(
      'Bosh::Cli::Client::Director',
      get_status: { 'version' => '1.2580.0' }
    )
  end
  let(:release_archive) { spec_asset('valid_release.tgz') }
  let(:release_manifest) { spec_asset(File.join('release', 'release.MF')) }
  let(:release_location) { 'http://release_location' }

  before do
    allow(command).to receive(:director).and_return(director)
  end

  describe 'create release' do
    let(:interactive) { true }
    let(:release) { instance_double('Bosh::Cli::Release', dev_name: 'a-release') }
    let(:question) { instance_double('HighLine::Question') }

    before do
      allow(command).to receive(:interactive?).and_return(interactive)
      allow(command).to receive(:check_if_release_dir)
      allow(command).to receive(:dirty_blob_check)
      allow(command).to receive(:dirty_state?).and_return(false)
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

    context 'when version is specified' do
      it 'builds release with the specified version' do
        expect(command).to receive(:build_release).with(true, nil, nil, true, [], '1.0.1')
        command.options[:version] = '1.0.1'
        command.create
      end
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

            expect { command.create }.to raise_error(Bosh::Cli::CliError, 'the message')
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

    context 'when a custom release version is given' do
      context 'and valid' do
        before do
          command.options[:version] = '1'
        end

        it 'does not print error message' do
          expect(command).to_not receive(:err)

          command.create
        end
      end

      context 'and not valid' do
        before do
          command.options[:version] = '1+1+1+1'
        end

        it 'prints the error message' do
          expected_error = 'Invalid version: `1+1+1+1\'. ' +
            'Please specify a valid version (ex: 1.0.0 or 1.0-beta.2+dev.10).'
          expect(command).to receive(:err).with(expected_error)

          command.create
        end
      end
    end

    context 'when a manifest file is given' do
      let(:manifest_file) { 'manifest_file.yml' }

      context 'when the manifest file exists' do
        it 'creates a release from the given manifest' do
          allow(File).to receive(:file?).with(manifest_file).and_return(true)
          allow(release).to receive(:blobstore).and_return('fake-blobstore')

          expect(Bosh::Cli::ReleaseCompiler).to receive(:compile).with(manifest_file, 'fake-blobstore')
          expect(release).to receive(:latest_release_filename=).with(manifest_file)
          expect(release).to receive(:save_config)

          command.create(manifest_file)
        end
      end

      context 'when the manifest file does not exist' do
        it 'goes through standard route to create a release from spec' do
          expect(release).to receive(:dev_name).and_return('fake-release-name')

          command.create(manifest_file)
        end
      end

      it 'does not allow a user-defined version' do
        command.options[:version] = '123'
        allow(File).to receive(:file?).with(manifest_file).and_return(true)

        expect { command.create(manifest_file) }.to raise_error(Bosh::Cli::CliError, 'Cannot specify a custom version number when creating from a manifest. The manifest already specifies a version.')
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
        before { allow(director).to receive(:get_release).and_raise(Bosh::Cli::ResourceNotFound) }
        before { allow(director).to receive(:match_packages).and_return([]) }

        describe 'converting to old format' do
          let!(:tarball) do
            instance_double(
              'Bosh::Cli::ReleaseTarball',
              validate: nil,
              valid?: true,
              release_name: 'fake-release-name',
              version: tarball_version,
              manifest: nil,
              repack: nil
            )
          end
          let(:tarball_version) { '8.1' }

          before { allow(Bosh::Cli::ReleaseTarball).to receive(:new).and_return(tarball) }

          before { allow(director).to receive(:upload_release) }

          before do
            allow(director).to receive(:get_status).and_return(
              {
                'version' => director_version
              }
            )
          end

          context 'when director is an older version and release is in new format' do
            let(:director_version) { '1.2579.0 (release:4fef83a2 bosh:4fef83a2)' }
            context 'when the tarball version can be converted to old format' do
              let(:tarball_version) { '8.1+dev.3' }

              it 'converts tarball version to the old format' do
                expect(tarball).to receive(:convert_to_old_format)
                command.upload(release_archive)
              end
            end

            context 'when the tarball version is already in the old format' do
              let(:tarball_version) { '8.1.3-dev' }

              it 'does not convert tarball version to the old format' do
                expect(tarball).to_not receive(:convert_to_old_format)
                command.upload(release_archive)
              end
            end

            context 'when the tarball version can not be converted to the old format' do
              let(:tarball_version) { '8.1' }

              it 'does not convert tarball version to the old format' do
                expect(tarball).to_not receive(:convert_to_old_format)
                command.upload(release_archive)
              end
            end
          end

          context 'when director is a new version' do
            let(:director_version) { '1.2580.0 (release:4fef83a2 bosh:4fef83a2)' }

            it 'does not convert tarball version to old format' do
              expect(tarball).to_not receive(:convert_to_old_format)
              command.upload(release_archive)
            end
          end
        end

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
          let(:tarball_path) { spec_asset('valid_release.tgz') }

          it 'uploads release and returns successfully' do
            expect(director).to receive(:upload_release).with(tarball_path)
            command.upload(tarball_path)
          end
        end

        context 'when release already exists' do
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

  describe 'list' do
    let(:releases) do
      [
        {
          'name' => 'bosh-release',
          'release_versions' => [
            {
              'version' => '0+dev.3',
              'commit_hash' => 'fake-hash-3',
              'currently_deployed' => false,
              'uncommitted_changes' => true
            },
            {
              'version' => '0+dev.2',
              'commit_hash' => 'fake-hash-2',
              'currently_deployed' => true,
            },
            {
              'version' => '0+dev.1',
              'commit_hash' => 'fake-hash-1',
              'currently_deployed' => false,
            }
          ],
        }
      ]
    end

    before do
      allow(command).to receive(:logged_in?).and_return(true)
      command.options[:target] = 'http://bosh-target.example.com'
      allow(director).to receive(:list_releases).and_return(releases)
    end

    it 'lists all releases' do
      command.list
      expect_output(<<-OUT)

      +--------------+----------+--------------+
      | Name         | Versions | Commit Hash  |
      +--------------+----------+--------------+
      | bosh-release | 0+dev.1  | fake-hash-1  |
      |              | 0+dev.2* | fake-hash-2  |
      |              | 0+dev.3  | fake-hash-3+ |
      +--------------+----------+--------------+
      (*) Currently deployed
      (+) Uncommitted changes

      Releases total: 1
      OUT
    end

    context 'when there is a deployed release' do
      let(:releases) do
        [
          {
            'name' => 'bosh-release',
            'release_versions' => [
              {
                'version' => '0+dev.3',
                'commit_hash' => 'fake-hash-3',
                'currently_deployed' => true,
                'uncommitted_changes' => false
              }
            ],
          }
        ]
      end

      it 'prints Currently deployed' do
        command.list
        expect_output(<<-OUT)

        +--------------+----------+-------------+
        | Name         | Versions | Commit Hash |
        +--------------+----------+-------------+
        | bosh-release | 0+dev.3* | fake-hash-3 |
        +--------------+----------+-------------+
        (*) Currently deployed

        Releases total: 1
        OUT
      end
    end

    context 'when there are releases with uncommited changes' do
      let(:releases) do
        [
          {
            'name' => 'bosh-release',
            'release_versions' => [
              {
                'version' => '0+dev.3',
                'commit_hash' => 'fake-hash-3',
                'currently_deployed' => false,
                'uncommitted_changes' => true
              }
            ],
          }
        ]
      end

      it 'prints Uncommited changes' do
        command.list
        expect_output(<<-OUT)

        +--------------+----------+--------------+
        | Name         | Versions | Commit Hash  |
        +--------------+----------+--------------+
        | bosh-release | 0+dev.3  | fake-hash-3+ |
        +--------------+----------+--------------+
        (+) Uncommitted changes

        Releases total: 1
        OUT
      end
    end
  end

  def expect_output(expected_output)
    actual = Bosh::Cli::Config.output.string
    indent = expected_output.scan(/^[ \t]*(?=\S)/).min.size || 0
    expect(actual).to eq(expected_output.gsub(/^[ \t]{#{indent}}/, ''))
  end
end
