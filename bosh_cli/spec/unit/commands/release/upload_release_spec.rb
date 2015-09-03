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
    let(:release_archive) { spec_asset('test_release.tgz') }
    let(:release_manifest) { spec_asset(File.join('release', 'release.MF')) }
    let(:release_location) { 'http://release_location' }

    let(:compiler) { instance_double('Bosh::Cli::ReleaseCompiler') }
    before { class_double('Bosh::Cli::ReleaseCompiler', new: compiler).as_stubbed_const }

    let(:release) { instance_double('Bosh::Cli::Release', blobstore: nil, dir: 'fake-release-dir') }
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
            context 'when release tarball is passed in' do
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

            context 'when release manifest is passed in' do
              let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
              before do
                release_source.add_dir('src')
                release_source.add_dir('jobs')
                release_source.add_file('config', 'final.yml', '{}')
                release_source.add_dir('packages')
                release_source.add_file('dev_releases/bosh', 'bosh-199+dev.1.yml', '---')
                release_source.add_file('releases', 'bosh-199.yml', '---')

                allow(command).to receive(:release).and_call_original
              end

              let(:dev_release_manifest_path) { File.join(release_source.path, 'dev_releases/bosh/bosh-199+dev.1.yml') }
              let(:final_release_manifest_path) { File.join(release_source.path, 'releases/bosh-199.yml') }

              context 'when not in release directory' do
                it 'uploads dev release successfully' do
                  expect(command).to receive(:upload_manifest)
                                       .with(dev_release_manifest_path, hash_including(:rebase => nil))
                                       .and_call_original
                  expect(compiler).to receive(:exists?).and_return(true)
                  allow(compiler).to receive(:tarball_path).and_return('fake-tarball-path')
                  expect(command).to receive(:upload_tarball).with('fake-tarball-path', hash_including(:rebase => nil))
                  command.upload(dev_release_manifest_path)
                end

                it 'uploads final release successfully' do
                  expect(command).to receive(:upload_manifest)
                                       .with(final_release_manifest_path, hash_including(:rebase => nil))
                                       .and_call_original
                  expect(compiler).to receive(:exists?).and_return(true)
                  allow(compiler).to receive(:tarball_path).and_return('fake-tarball-path')
                  expect(command).to receive(:upload_tarball).with('fake-tarball-path', hash_including(:rebase => nil))
                  command.upload(final_release_manifest_path)
                end
              end
            end

            context 'when release is not passed in' do
              context 'when not in release directory' do
                let(:tmp_dir) { Dir.mktmpdir('upload-release-spec') }
                before do
                  @original_directory = Dir.pwd
                  Dir.chdir(tmp_dir)
                end

                after do
                  Dir.chdir(@original_directory)
                  FileUtils.rm_rf(tmp_dir)
                end

                let(:command_in_not_release_directory) do
                  command = described_class.new
                  allow(command).to receive(:release).and_return(release)
                  allow(command).to receive(:director).and_return(director)
                  allow(command).to receive(:show_current_state)
                  allow(command).to receive(:logged_in?).and_return(true)
                  command.options[:target] = 'http://bosh-target.example.com'
                  command
                end

                context 'when --dir option is not passed in' do
                  it 'raises an error' do
                    expect {
                      command_in_not_release_directory.upload
                    }.to raise_error Bosh::Cli::CliError, /Sorry, your current directory doesn't look like release directory/
                  end
                end

                context 'when --dir option is passed in' do
                  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
                  let(:latest_release_filename) do
                    file_path = Tempfile.new('upload-release-spec')
                    File.write(file_path.path, '{}')
                    file_path
                  end

                  before do
                    release_source.add_dir('jobs')
                    release_source.add_dir('packages')
                    release_source.add_dir('src')
                    allow(release).to receive(:latest_release_filename).and_return(latest_release_filename.path)
                    command_in_not_release_directory.options[:dir] = release_source.path
                  end
                  after { latest_release_filename.delete }

                  it 'uploads release' do
                    expect(command_in_not_release_directory).to receive(:upload_manifest)

                    expect {
                      command_in_not_release_directory.upload
                    }.to_not raise_error
                  end
                end
              end
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
            let(:tarball_path) { spec_asset('test_release.tgz') }
            let(:valid_release_tarball_path) { spec_asset('valid_release.tgz') }

            it 'uploads release and returns successfully' do
              expect(director).to receive(:upload_release).with(tarball_path, hash_including(:rebase => nil))
              command.upload(tarball_path)
            end

            it 'uploads a release tarball wihout fingerprints and returns successfully' do
              expect(director).to receive(:upload_release).with(valid_release_tarball_path, hash_including(:rebase => nil))
              command.upload(valid_release_tarball_path)
            end
          end

          context 'when uploading compiled release tarball' do
            let(:tarball_path) { spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz') }

            it 'should not check if file is in release directory' do
              allow(director).to receive(:upload_release)
              allow(director).to receive(:match_compiled_packages)
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
              let(:tarball_path) { spec_asset('test_release.tgz') }

              it 'does upload release' do
                expect(director).to receive(:upload_release)
                command.upload(tarball_path)
              end
           end

            context 'when the director is an old version' do
              let(:director_version) { '1.2579.0 (release:4fef83a2 bosh:4fef83a2)' }

              before { allow(director).to receive(:get_release).and_return(
                {'jobs' => nil, 'packages' => nil, 'versions' => ['0.1-dev']}) }
              let(:tarball_path) { spec_asset('test_release.tgz') }

              it 'does upload release' do
                expect(director).to receive(:upload_release)
                command.upload(tarball_path)
              end
            end
          end
        end

        context 'remote release' do
          context 'without options' do
            it 'should upload the release' do
              expect(command).to receive(:upload_remote_release)
                .with(release_location, hash_including(:rebase => nil))
                .and_call_original
              expect(director).to receive(:upload_remote_release).with(
                release_location,
                hash_including(:rebase => nil),
              )

              command.upload(release_location)
            end
          end

          context 'with options' do
            it 'should upload the release' do
              expect(command).to receive(:upload_remote_release)
                .with(release_location, hash_including(:rebase => true))
                .and_call_original
              expect(director).to receive(:upload_remote_release).with(
                release_location,
                hash_including(:rebase => true),
              )

              command.add_option(:rebase, true)
              command.upload(release_location)
            end
          end
        end
      end
    end
  end
end
