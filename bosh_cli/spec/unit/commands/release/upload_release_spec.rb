require 'spec_helper'

module Bosh::Cli::Command::Release
  describe UploadRelease do
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

    let(:compiler) { instance_double('Bosh::Cli::ReleaseCompiler') }
    before { class_double('Bosh::Cli::ReleaseCompiler', new: compiler).as_stubbed_const }

    let(:release) { instance_double('Bosh::Cli::Release', blobstore: nil) }
    before { allow(command).to receive(:release).and_return(release) }

    before do
      allow(command).to receive(:director).and_return(director)
      allow(command).to receive(:show_current_state)
    end

    describe '#upload' do
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

            before {
              allow(Bosh::Cli::ReleaseTarball).to receive(:new).and_return(tarball)
              allow(tarball).to receive(:compiled_release?).and_return(false)

              allow(director).to receive(:upload_release)
              allow(director).to receive(:get_status).and_return({'version' => director_version})
            }

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
            it 'should upload the release archive indicated by a manifest' do
              allow(compiler).to receive(:exists?).and_return(true)
              allow(compiler).to receive(:tarball_path).and_return(release_archive)

              expect(command).to receive(:upload_manifest)
                .with(release_manifest, hash_including(:rebase => nil))
                .and_call_original
              expect(director).to receive(:upload_release).with(release_archive, hash_including(:rebase => nil))
              command.upload(release_manifest)
            end

            it 'should upload a release archive' do
              expect(command).to receive(:upload_tarball)
                .with(release_archive, hash_including(:rebase => nil))
                .and_call_original
              expect(director).to receive(:upload_release).with(release_archive, hash_including(:rebase => nil))
              command.upload(release_archive)
            end
          end

          context 'with rebase' do
            it 'should upload the release archive indicated by a manifest' do
              allow(compiler).to receive(:exists?).and_return(true)
              allow(compiler).to receive(:tarball_path).and_return(release_archive)

              expect(command).to receive(:upload_manifest)
                .with(release_manifest, hash_including(:rebase => true))
                .and_call_original
              expect(director).to receive(:upload_release).with(release_archive, hash_including(:rebase => true))
              command.add_option(:rebase, true)
              command.upload(release_manifest)
            end

            it 'should upload the release archive' do
              expect(command).to receive(:upload_tarball)
                .with(release_archive, hash_including(:rebase => true))
                .and_call_original
              expect(director).to receive(:upload_release).with(release_archive, hash_including(:rebase => true))
              command.add_option(:rebase, true)
              command.upload(release_archive)
            end
          end

          context 'when release does not exist' do
            let(:tarball_path) { spec_asset('valid_release.tgz') }

            it 'uploads release and returns successfully' do
              expect(director).to receive(:upload_release).with(tarball_path, hash_including(:rebase => nil))
              command.upload(tarball_path)
            end
          end

          context 'when uploading compiled release tarball' do
            let(:tarball_path) { spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz') }

            it 'should not check if file is in release directory' do
              allow(director).to receive(:upload_release)
              expect(command).to_not receive(:check_if_release_dir)
              command.upload(tarball_path)
            end
          end

          context 'when release already exists' do
            before do
              allow(director).to receive(:get_status).and_return(
                {
                  'version' => director_version
                }
              )
            end

            context 'when the director is a new version' do
              let(:director_version) { '1.2580.0 (release:4fef83a2 bosh:4fef83a2)' }
              before { allow(director).to receive(:get_release).and_return(
                {'jobs' => nil, 'packages' => nil, 'versions' => ['0+dev.1']}) }
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

            context 'when the director is an old version' do
              let(:director_version) { '1.2579.0 (release:4fef83a2 bosh:4fef83a2)' }

              before { allow(director).to receive(:get_release).and_return(
                {'jobs' => nil, 'packages' => nil, 'versions' => ['0.1-dev']}) }
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
        end

        context 'remote release' do
          context 'without options' do
            it 'should upload the release' do
              expect(command).to receive(:upload_remote_release)
                .with(release_location, hash_including(:rebase => nil, :skip_if_exists => nil))
                .and_call_original
              expect(director).to receive(:upload_remote_release).with(
                release_location,
                hash_including(:rebase => nil, :skip_if_exists => nil),
              )

              command.upload(release_location)
            end
          end

          context 'with options' do
            it 'should upload the release' do
              expect(command).to receive(:upload_remote_release)
                .with(release_location, hash_including(:rebase => true, :skip_if_exists => true))
                .and_call_original
              expect(director).to receive(:upload_remote_release).with(
                release_location,
                hash_including(:rebase => true, :skip_if_exists => true),
              )

              command.add_option(:rebase, true)
              command.add_option(:skip_if_exists, true)
              command.upload(release_location)
            end
          end
        end
      end
    end
  end
end
