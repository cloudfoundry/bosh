require 'spec_helper'

module Bosh::Cli::Command::Release
  describe CreateRelease do
    subject(:command) { CreateRelease.new }

    describe '#create' do
      let(:release) do
        instance_double(
          'Bosh::Cli::Release',
          dev_name: configured_dev_name,
          final_name: configured_final_name,
          blobstore: nil,
          dir: release_source.path,
        )
      end
      let(:question) { instance_double('HighLine::Question') }
      let(:configured_dev_name) { 'a-release' }
      let(:configured_final_name) { 'b-release' }
      let(:release_builder) { instance_double('Bosh::Cli::ReleaseBuilder') }
      let(:next_dev_version) { '0+dev.1' }
      let(:previous_manifest_path) { nil }
      let(:next_manifest_path) do
        release_source.join(
          'dev_releases',
          configured_dev_name,
          "#{configured_dev_name}-#{next_dev_version}.yml"
        )
      end

      let(:next_tarball_path) do
        release_source.join(
          'dev_releases',
          configured_dev_name,
          "#{configured_dev_name}-#{next_dev_version}.tgz"
        )
      end

      let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
      let(:release_options) do
        {
          dry_run: false,
          final: false
        }
      end
      let(:archive_dir) { release_source.path }
      let(:cache_dir) { release_source.artifacts_dir }
      let(:blobstore) { double('blobstore') }
      let(:package) {
        Bosh::Cli::Resources::Package.new(release_source.join('packages/package_name'), release_source.path)
      }
      let(:license) {
        Bosh::Cli::Resources::License.new(release_source.path)
      }
      let(:job) {
        Bosh::Cli::Resources::Job.new(release_source.join('jobs/job_name'), release_source.path, [package.name])
      }
      let(:package_spec) do
        {
          'name' => 'package_name',
          'files' => ['lib/*.rb', 'README.*'],
          'dependencies' => [],
          'excluded_files' => [],
        }
      end
      let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
      let(:archive_repository_provider) { Bosh::Cli::ArchiveRepositoryProvider.new(archive_dir, cache_dir, blobstore) }
      let(:archive_builder) { Bosh::Cli::ArchiveBuilder.new(archive_repository_provider, release_options) }
      let(:job_spec) do
        {
          'name' => 'job_name',
          'packages' => ['package_name'],
          'templates' => { 'a.conf' => 'a.conf' },
        }
      end
      let(:job_templates) { ['a.conf'] }

      before do
        release_source.add_file('jobs/job_name', 'spec', job_spec.to_yaml)
        release_source.add_file('jobs/job_name', 'monit')
        release_source.add_files('jobs/job_name/templates', job_templates)

        release_source.add_dir('src')
        release_source.add_file('packages/package_name', 'spec', package_spec.to_yaml)

        matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }

        allow(Bosh::Cli::Resources::Package).to receive(:discover).and_return([package])
        allow(Bosh::Cli::Resources::License).to receive(:discover).and_return([license])
        allow(Bosh::Cli::Resources::Job).to receive(:discover).and_return([job])
        allow(Bosh::Cli::ArchiveBuilder).to receive(:new).and_return(archive_builder)

        allow(release).to receive(:latest_release_filename=)
        allow(release).to receive(:save_config)
      end

      after do
        release_source.cleanup
      end

      it 'is a command with the correct options' do
        command = Bosh::Cli::Config.commands['create release']
        expect(command).to have_options
        expect(command.options.map(&:first)).to match_array([
          '--force',
          '--final',
          '--with-tarball',
          '--dry-run',
          '--name NAME',
          '--version VERSION',
          '--dir RELEASE_DIRECTORY',
        ])
      end

      context 'when current directory is release directory' do
        before do
          @original_directory = Dir.pwd
          Dir.chdir(release_source.path)

          allow(command).to receive(:cache_dir) { cache_dir }
          allow(command).to receive(:dirty_blob_check)
          allow(command).to receive(:dirty_state?).and_return(false)
          allow(command).to receive(:release).and_return(release)
          command.options[:dry_run] = true
        end

        after do
          Dir.chdir(@original_directory)
        end

        context 'when the release has NO license' do
          it 'prints status' do
            command.create

            output = Bosh::Cli::Config.output.string
            expect(output).to match(/^\s*Warning: Missing LICENSE or NOTICE in/)
          end

          context 'given --with-tarball' do
            before do
              command.options[:dry_run] = false
              command.options[:with_tarball] = true
            end

            it 'prints status' do
              allow(command).to receive(:cache_dir).and_return('fake-cache-dir')
              command.create

              output = Bosh::Cli::Config.output.string
              expect(output).to match(/^Generated .*\.tgz$/)
              expect(output).to match(/^Release size: \d/)
              expect(output).to match(/^Release tarball \(\d.*\): .*\.tgz$/)
            end
          end
        end

        context 'when the release has license' do
          before { release_source.add_file(nil, 'LICENSE', 'fake-license') }

          it 'prints status' do
            allow(command).to receive(:cache_dir).and_return('fake-cache-dir')
            command.create

            output = Bosh::Cli::Config.output.string
            expect(output).to match(/^Building license$/)
            expect(output).to match(/^\s*No artifact found for license$/)
            expect(output).to match(/^\s*Generating...$/)
          end

          it 'builds release with the license' do
            command.create
            license_version_index = Bosh::Cli::Versions::VersionsIndex.new(release_source.join('.dev_builds', 'license'))
            license_sha1 = license_version_index['f47faccb943d1df02c4ed75fb4fd488add35b003']['sha1']
            expect(release_source).to have_artifact(license_sha1)
          end

          context 'given --with-tarball' do
            before do
              command.options[:dry_run] = false
              command.options[:with_tarball] = true
              release_source.add_file(nil, 'LICENSE', 'fake-license')
            end

            it 'prints status' do
              allow(command).to receive(:cache_dir).and_return('fake-cache-dir')
              command.create


              output = Bosh::Cli::Config.output.string
              expect(output).to match(/^Generated .*\.tgz$/)
              expect(output).to match(/^Release size: \d/)
              expect(output).to match(/^Release tarball \(\d.*\): .*\.tgz$/)
            end
          end
        end

        context 'when a final name is configured' do
          let(:configured_final_name) { 'd-release' }

          it 'attempts to migrate the releases to the latest format' do
            multi_release_support = instance_double('Bosh::Cli::Versions::MultiReleaseSupport')
            expect(Bosh::Cli::Versions::MultiReleaseSupport).to receive(:new).
                with(release_source.path, configured_final_name, command).
                and_return(multi_release_support)
            expect(multi_release_support).to receive(:migrate)

            command.create
          end
        end

        context 'when a final name is not configured' do
          let(:configured_final_name) { nil }

          it 'attempts to migrate the releases to the latest format' do
            expect(Bosh::Cli::Versions::MultiReleaseSupport).to_not receive(:new)

            command.create
          end
        end

        context 'when a name is provided with --name' do
          let(:provided_name) { 'c-release' }

          before do
            command.options[:name] = provided_name
            expect(Bosh::Cli::Resources::Package).to receive(:discover).with(release_source.path).and_return([package])
          end

          it 'builds release with the specified name' do
            package_artifact = archive_builder.build(package)
            job_artifact = archive_builder.build(job)
            expect(archive_builder).to receive(:build).and_return(nil, package_artifact, job_artifact)
            expect(command).to receive(:build_release)
                                 .with([job_artifact], true, [package_artifact], [], provided_name, nil)
                                 .and_call_original

            command.create
          end

          it 'does not modify the name configuration' do
            expect(release).to_not receive(:dev_name=)
            expect(release).to_not receive(:final_name=)

            command.create
          end
        end

        context 'when a version is provided with --version' do
          it 'builds release with the specified version' do
            package_artifact = archive_builder.build(package)
            job_artifact = archive_builder.build(job)
            expect(archive_builder).to receive(:build).and_return(nil, package_artifact, job_artifact)
            expect(command).to receive(:build_release)
                                 .with([job_artifact], true, [package_artifact], [], configured_final_name, '1.0.1')
                                 .and_call_original

            command.options[:version] = '1.0.1'
            command.options[:final] = true
            command.options[:non_interactive] = true
            command.create
          end
        end


        context 'dev release' do
          context 'interactive' do
            before { command.options[:non_interactive] = false }

            context 'when final release name is not set' do
              it 'development release name prompt should not have any default' do
                expect(release).to receive(:dev_name).and_return(nil)
                allow(release).to receive(:final_name).and_return(nil)
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
                allow(release).to receive(:final_name).and_return('test-release')
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
            before { command.options[:non_interactive] = true }

            context 'when final config does not include a final release name' do
              it 'development release name should default to bosh-release' do
                expect(release).to receive(:dev_name).and_return(nil)
                allow(release).to receive(:final_name).and_return(nil)
                expect(release).to receive(:dev_name=).with('bosh-release')

                command.create
              end
            end

            context 'when final config includes a final release name' do
              it 'development release name should be final release name' do
                expect(release).to receive(:dev_name).and_return(nil)
                allow(release).to receive(:final_name).and_return('test')
                expect(release).to receive(:dev_name=).with('test')

                command.create
              end
            end
          end
        end

        context 'final release' do
          before do
            command.options[:final] = true
            command.options[:non_interactive] = true
          end

          context 'when a release version is provided' do
            context 'and is valid' do
              before { command.options[:version] = '1' }

              it 'does not print error message' do
                expect(command).to_not receive(:err)

                command.create
              end
            end

            context 'and is not valid' do
              before { command.options[:version] = '1+1+1+1' }

              it 'prints the error message' do
                expected_error = "Invalid version: '1+1+1+1'. " +
                  'Please specify a valid version (ex: 1.0.0 or 1.0-beta.2+dev.10).'
                expect(command).to receive(:err).with(expected_error)

                command.create
              end
            end
          end
        end

        context 'when a manifest file is provided' do
          let(:manifest_file) { 'manifest_file.yml' }

          context 'when the manifest file exists' do
            it 'creates a release from the provided manifest' do
              allow(File).to receive(:file?).with(manifest_file).and_return(true)
              allow(release).to receive(:blobstore).and_return('fake-blobstore')

              expect(Bosh::Cli::ReleaseCompiler).to receive(:compile).with(manifest_file, release_source.artifacts_dir, 'fake-blobstore', [], release_source.path)
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

      context 'when a directory is not release directory' do
        let(:tmp_dir) { Dir.mktmpdir('create-release-spec') }
        before do
          @original_directory = Dir.pwd
          Dir.chdir(tmp_dir)

          allow(command).to receive(:cache_dir) { cache_dir }
          allow(command).to receive(:dirty_blob_check)
          allow(command).to receive(:dirty_state?).and_return(false)
          allow(command).to receive(:release).and_return(release)

          release_source.git_init
        end

        after do
          Dir.chdir(@original_directory)
          FileUtils.rm_rf(tmp_dir)
        end

        context 'when the --dir is not passed in' do
          it 'raises an error' do
            expect {
              command.create
            }.to raise_error Bosh::Cli::CliError, /Sorry, your current directory doesn't look like release directory/
          end
        end

        context 'when --dir is passed in' do
          before do
            command.options[:dir] = release_source.path
            command.options[:dry_run] = false
          end

          context 'when creating without manifest file' do
            it 'builds release' do
              expect {
                command.create
              }.not_to raise_error

              expect(File.exists?(next_manifest_path)).to be_truthy
            end

            it 'generates correct commit sha' do
              command.create
              next_release_manifest = Psych.load(File.read(next_manifest_path))
              expect(next_release_manifest['commit_hash']).to_not eq('00000000')
            end
          end

          context 'when creating from manifest file' do
            let!(:manifest_path) do
              command.create
              next_manifest_path
            end

            it 'builds release' do
            package_path = File.join(release_source.path, '.dev_builds', 'packages', 'package_name')
              command.options[:with_tarball] = true

              expect {
                command.create(manifest_path)
              }.not_to raise_error

              expect(File.exists?(next_tarball_path)).to be_truthy
            end

            it 'generates correct commit sha' do
              command.create
              next_release_manifest = Psych.load(File.read(next_manifest_path))
              expect(next_release_manifest['commit_hash']).to_not eq('00000000')
            end
          end
        end
      end
    end
  end
end
