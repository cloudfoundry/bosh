require 'spec_helper'

module Bosh::Cli::Versions
  describe ReleasesDirMigrator do
    include FakeFS::SpecHelpers

    let(:migrator) { ReleasesDirMigrator.new(releases_path, default_release_name, ui, release_type_name) }
    let(:default_release_name) { 'fake-release-name' }
    let(:ui) { double('FakeUI') }
    let(:release_type_name) { 'DEV' }

    describe '#needs_migration?' do
      let(:tmp_path) { Dir.mktmpdir }
      after { FileUtils.rm_r(tmp_path) }

      let(:releases_path) { File.join(tmp_path, 'releases') }
      let(:index_path) { File.join(releases_path, 'index.yml') }

      context 'when releases dir exists' do
        before { FileUtils.mkdir_p(releases_path) }

        context 'when index.yml exists in the releases dir' do
          let(:index_contents) do
            {
              'builds' => {
                'fake-version' => {
                  'version' => '1'
                }
              }
            }
          end

          it 'raises an exception if the contents of index.yml is not a hash' do
            contents = 2
            File.open(index_path, 'w') { |f| f.write(Psych.dump(contents)) }

            expect{
              migrator.needs_migration?
            }.to raise_error(Bosh::Cli::InvalidIndex)
          end

          it 'returns true if index.yml does not contain a format-version' do
            VersionsIndex.write_index_yaml(index_path, index_contents)

            expect(migrator.needs_migration?).to eq(true)
          end

          it 'returns true if index.yml exists and has a format-version < 2' do
            VersionsIndex.write_index_yaml(index_path, index_contents.merge('format-version' => '1'))

            expect(migrator.needs_migration?).to eq(true)
          end

          it 'returns false if index.yml exists and has a format-version >= 2' do
            VersionsIndex.write_index_yaml(index_path, index_contents.merge('format-version' => '2'))

            expect(migrator.needs_migration?).to eq(false)
          end
        end

        context 'when index.yml does not exist' do
          it 'returns false' do
            expect(migrator.needs_migration?).to eq(false)
          end
        end
      end

      context 'when releases dir does not exist' do
        it 'returns false' do
          expect(migrator.needs_migration?).to eq(false)
        end
      end
    end

    describe '#migrate' do
      let(:tmp_path) { Dir.mktmpdir }
      after { FileUtils.rm_r(tmp_path) }

      let(:releases_path) { File.join(tmp_path, 'releases') }

      context 'when migration is needed' do
        before do
          allow(migrator).to receive(:needs_migration?).and_return(true)
        end

        before { FileUtils.mkdir_p(releases_path) }

        let(:index_path) { File.join(releases_path, 'index.yml') }
        let(:version1) do
          {
            'version' => '1',
            'sha1' => 'fake-sha1',
            'blobstore_id' => 'fake-blobstore-id-1',
          }
        end
        let(:version2) do
          {
            'version' => '2',
            'sha1' => 'fake-sha1',
            'blobstore_id' => 'fake-blobstore-id-2',
          }
        end

        let(:default_release_name) { 'bosh-release' }

        context 'when the releases dir contains releases' do
          before do
            FileUtils.touch(File.join(releases_path, 'bosh-release-1.tgz'))
            release_manifest1_path = File.join(releases_path, 'bosh-release-1.yml')
            release_manifest1 = { 'name' => 'bosh-release', 'version' => '1' }
            File.open(release_manifest1_path, 'w') { |f| f.write(Psych.dump(release_manifest1)) }

            FileUtils.touch(File.join(releases_path, 'renamed-release-2.tgz'))
            release_manifest2_path = File.join(releases_path, 'renamed-release-2.yml')
            release_manifest2 = { 'name' => 'renamed-release', 'version' => '2' }
            File.open(release_manifest2_path, 'w') { |f| f.write(Psych.dump(release_manifest2)) }

            VersionsIndex.write_index_yaml(index_path, {
              'builds' => {
                'fake-key-1' => version1,
                'fake-key-2' => version2,
              }
            })
          end

          it 'prints status messages to the user' do
            expect(ui).to receive(:header).with("Migrating #{release_type_name} releases")
            expect(ui).to receive(:say).with('Migrating release: renamed-release')
            expect(ui).to receive(:say).with('Migrating default release: bosh-release')

            migrator.migrate
          end

          it 'moves releases that are not the default release name to a subdir' do
            new_release_path = File.join(releases_path, 'renamed-release')
            expect(Dir).to_not exist(new_release_path)

            migrator.migrate

            expect(Dir).to exist(new_release_path)

            expect(File).to_not exist(File.join(releases_path, 'renamed-release-2.tgz'))
            expect(File).to exist(File.join(new_release_path, 'renamed-release-2.tgz'))

            expect(File).to_not exist(File.join(releases_path, 'renamed-release-2.yml'))
            expect(File).to exist(File.join(new_release_path, 'renamed-release-2.yml'))

            new_index_path = File.join(new_release_path, 'index.yml')
            expect(File).to exist(new_index_path)

            old_index = VersionsIndex.load_index_yaml(index_path)
            expect(old_index['builds']).to_not have_key('fake-key-2')

            new_index = VersionsIndex.load_index_yaml(new_index_path)
            expect(new_index['builds']['fake-key-2']).to eq(version2)
          end

          it 'does not move releases that have the default release name' do
            expect(File).to exist(File.join(releases_path, 'bosh-release-1.tgz'))
            expect(File).to exist(File.join(releases_path, 'bosh-release-1.yml'))
            expect(File).to exist(index_path)

            migrator.migrate

            expect(File).to exist(File.join(releases_path, 'bosh-release-1.tgz'))
            expect(File).to exist(File.join(releases_path, 'bosh-release-1.yml'))
            expect(File).to exist(index_path)

            old_index = VersionsIndex.load_index_yaml(index_path)
            expect(old_index['builds']['fake-key-1']).to eq(version1)
          end
        end

        it 'creates a relative symlink dir for the default release name' do
          symlink_path = File.join(releases_path, default_release_name)
          expect(File).to_not exist(symlink_path)

          migrator.migrate

          expect(File).to exist(symlink_path)
          expect(File.symlink?(symlink_path)).to eq(true)
          expect(File.readlink(symlink_path)).to eq('.')
        end

        it 'updates the format-version in the version index' do
          migrator.migrate

          old_index = VersionsIndex.load_index_yaml(index_path)
          expect(old_index['format-version']).to eq('2')
        end

        it 'returns true' do
          expect(migrator.migrate).to eq(true)
        end
      end

      context 'when migration is not needed' do
        before do
          allow(migrator).to receive(:needs_migration?).and_return(false)
        end

        it 'returns false & does not migrate' do
          expect(migrator.migrate).to eq(false)
        end
      end
    end
  end
end
