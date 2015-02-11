require 'spec_helper'

module Bosh::Cli::Versions
  describe VersionsIndex do
    let(:versions_index) { VersionsIndex.new(tmp_dir) }
    let(:tmp_dir) { Dir.mktmpdir }
    let(:index_file) { File.join(tmp_dir, 'index.yml') }
    let(:name) { 'build-name' }

    after { FileUtils.rm_rf(tmp_dir) }

    describe 'self.load_index_yaml' do
      let(:tmp_path) { Dir.mktmpdir }
      after { FileUtils.rm_r(tmp_path) }

      let(:index_path) { File.join(tmp_path, 'index.yml') }

      it 'loads the yml if it is a hash' do
        contents = { 'fake-contents' => 'fake' }
        VersionsIndex.write_index_yaml(index_path, contents)

        expect(VersionsIndex.load_index_yaml(index_path)).to eq(contents)
      end

      it 'loads the yml if it is empty' do
        FileUtils.touch(index_path)

        expect(VersionsIndex.load_index_yaml(index_path)).to eq(nil)
      end

      it 'raises an InvalidIndex error if the yml does not contain a hash' do
        contents = 2
        File.open(index_path, 'w') { |f| f.write(contents) }

        expect { VersionsIndex.load_index_yaml(index_path) }.to raise_error(Bosh::Cli::InvalidIndex)
      end
    end

    describe 'self.write_index_yaml' do
      let(:tmp_path) { Dir.mktmpdir }
      after { FileUtils.rm_r(tmp_path) }

      let(:index_path) { File.join(tmp_path, 'index.yml') }

      it 'writes the provided contents as yaml to the provided file' do
        contents = { 'fake-contents' => 'fake' }
        VersionsIndex.write_index_yaml(index_path, contents)

        expect(VersionsIndex.load_index_yaml(index_path)).to eq(contents)
      end

      it 'raises an InvalidIndex error if the yml does not contain a hash' do
        contents = 2

        expect { VersionsIndex.write_index_yaml(index_path, contents) }.to raise_error(Bosh::Cli::InvalidIndex)
      end
    end

    describe '#initialize' do
      it 'errors if the index file is malformed' do
        File.open(index_file, 'w') { |f| f.write('fake index file') }

        expect {
          versions_index = VersionsIndex.new(tmp_dir)
        }.to raise_error(Bosh::Cli::InvalidIndex)
      end

      it 'allows index file to be empty' do
        File.open(index_file, 'w') { |f| f.write('') }

        versions_index = VersionsIndex.new(tmp_dir)
        expect(versions_index.version_strings).to be_empty
      end

      it 'allows index file to not contain format-version' do
        old_index_hash = {'builds' => { 'fake-key' => { 'version' => 'fake-version' } }}
        File.open(index_file, 'w') { |f| f.write(Psych.dump(old_index_hash)) }

        expect {
          VersionsIndex.new(tmp_dir)
        }.to_not raise_error
      end
    end

    describe '#save' do
      it 'writes defaults to disk' do
        expect(File).to_not exist(index_file)

        versions_index.save

        expect(File).to exist(index_file)

        data = VersionsIndex.load_index_yaml(index_file)
        expect(data['builds']).to eq({})
        expect(data['format-version']).to eq(VersionsIndex::CURRENT_INDEX_VERSION.to_s)
      end
    end

    describe '#add_version' do
      it 'lazily creates index file when a version has been added' do
        expect(File).to_not exist(index_file)

        versions_index.add_version('fake-key', { 'version' => 2 })
        expect(File).to exist(index_file)
        expect(load_yaml_file(index_file)).to include(
          'builds' => {
            'fake-key' => {
              'version' => 2
            }
          }
        )
      end

      it 'lazily initializes the format-version' do
        expect(File).to_not exist(index_file)

        versions_index.add_version('fake-key', { 'version' => 'fake-version' })
        expect(load_yaml_file(index_file)).to include('format-version' => VersionsIndex::CURRENT_INDEX_VERSION.to_s)
      end

      context 'when storage dir does not exist' do
        let(:versions_index) { VersionsIndex.new(missing_storage_dir) }
        let(:missing_storage_dir) { File.join(tmp_dir, 'missing-dir') }

        it 'lazily creates storage dir when a version has been added' do
          expect(Dir).to_not exist(missing_storage_dir)

          versions_index.add_version('fake-key', { 'version' => 2 })
          expect(Dir).to exist(missing_storage_dir)
        end
      end

      it 'records the versioned build data and returns the version' do
        build1 = { 'a' => 1, 'b' => 2, 'version' => 1 }
        build2 = { 'a' => 3, 'b' => 4, 'version' => 2 }

        version1 = versions_index.add_version('fake-key-1', build1)
        version2 = versions_index.add_version('fake-key-2', build2)

        expect(version1).to be(1)
        expect(version2).to be(2)

        expect(versions_index['fake-key-1']).to eq(build1)
        expect(versions_index['fake-key-2']).to eq(build2)
      end

      it 'errors if the build data does not include a version' do
        build_without_version = { 'a' => 1, 'b' => 2 }
        expect {
          versions_index.add_version('fake-key', build_without_version)
        }.to raise_error(
          Bosh::Cli::InvalidIndex,
          "Cannot save index entry without a version: `#{build_without_version}'"
        )
      end

      it 'does not allow duplicate versions with different keys' do
        version = '1.9-dev'
        item1 = { 'version' => version }

        versions_index.add_version('fake-key-1', item1)

        expect {
          versions_index.add_version('fake-key-2', item1)
        }.to raise_error(
          "Trying to add duplicate version `#{version}' into index `#{File.join(tmp_dir, 'index.yml')}'"
        )
      end

      it 'does not overwrite a payload with identical fingerprint' do
        item1 = { 'a' => 1, 'b' => 2, 'version' => '1.8-dev' }
        item2 = { 'b' => 2, 'c' => 3, 'version' => '1.9-dev' }

        versions_index.add_version('fake-key', item1)
        expect {
          versions_index.add_version('fake-key', item2)
        }.to raise_error(
          "Trying to add duplicate entry `fake-key' into index `#{File.join(tmp_dir, 'index.yml')}'"
        )
        expect(versions_index['fake-key']).to eq(item1)
      end
    end

    context 'when versions are loaded from the index file' do
      before do
        old_index_hash = {'builds' => { 'fake-key' => { 'version' => 'fake-version' } }}
        File.open(index_file, 'w') { |f| f.write(Psych.dump(old_index_hash)) }
      end

      describe '#update_version' do
        it 'lazily initializes the format-version' do
          versions_index.update_version('fake-key', { 'version' => 'fake-version', 'sha1' => 'fake-sha1' })
          expect(load_yaml_file(index_file)).to include('format-version' => VersionsIndex::CURRENT_INDEX_VERSION.to_s)
        end
      end
    end

    context 'after versions have been added' do
      let(:builds) do
        {
          'fake-key-1' => { 'a' => 1, 'b' => 2, 'version' => 1 },
          'fake-key-2' => { 'a' => 3, 'b' => 4, 'version' => 2 },
          'fake-key-3' => { 'a' => 5, 'b' => 6, 'version' => 3 },
        }
      end

      before { builds.each{ |k, v| versions_index.add_version(k, v) } }

      describe '#each' do
        it 'executes the block on each hash entry' do
          versions_index.each { |k, v| expect(v).to eq(builds[k]) }
        end
      end

      describe '#select' do
        it 'calls select on the build hash' do
          selected = versions_index.select { |k, v| v['version'] > 1 }
          expected = builds.select { |k, v| v['version'] > 1 }

          expect(selected).to eq(expected)
        end
      end

      describe '#find' do
        it 'calls find on the build hash' do
          found = versions_index.find { |k, v| v['version'] == 2 }
          expected = builds.find { |k, v| v['version'] == 2 }

          expect(found).to eq(expected)
        end
      end

      describe '#update_version' do
        it 'replaces the build data indexed by the given key & returns the index file path' do
          build_data = versions_index['fake-key-2'].merge('a' => 10)

          versions_index.update_version('fake-key-2', build_data)
          expect(versions_index['fake-key-2']).to eq(build_data)
        end

        it 'errors if the build does not already exist' do
          expect{
            versions_index.update_version('fake-key-4', { 'version' => 4 })
          }.to raise_error(
            "Cannot update non-existent entry with key `fake-key-4'"
          )
        end

        it 'errors if the new version does not match the old version' do
          old_build = versions_index['fake-key-2']
          new_build = versions_index['fake-key-2'].merge('version' => 10)

          expect{
            versions_index.update_version('fake-key-2', new_build)
          }.to raise_error(
            "Cannot update entry `#{old_build}' with a different version: `#{new_build}'"
          )
        end
      end

      describe '#remove_version' do
        it 'errors if the entry does not exist' do
          expect { versions_index.remove_version('non-existant-key') }.to raise_error
        end

        it 'removes the entry if it exists' do
          versions_index.add_version('fake-key', { 'version' => 'fake-version' })

          versions_index.remove_version('fake-key')

          expect(versions_index['fake-key']).to be_nil
        end
      end

      describe '#find_key_by_version' do
        it 'returns the key associated with the provided version' do
          versions_index.add_version('fake-key-61', { 'version' => '61' })
          versions_index.add_version('fake-key-63', { 'version' => '63' })

          expect(versions_index.find_key_by_version('61')).to eq('fake-key-61')
        end

        it 'returns nil if the version is not found' do
          expect(versions_index.find_key_by_version('293')).to be_nil
        end
      end

      describe '#version_strings' do
        it 'returns an array of the versions as strings' do
          expect(versions_index.version_strings).to eq(['1', '2', '3'])
        end
      end

      describe '#to_s' do
        it 'returns a string representation for debugging' do
          expect(versions_index.to_s).to eq(builds.to_s)
        end
      end
    end

    context 'when old build has blobstore_id' do
      before do
        versions_index.add_version('fake-key-with-blobstore-id', {
            'blobstore_id' => 'fake-blobstore-id',
            'version' => 4
          })
      end

      it 'errors to update_version' do
        expect{
          versions_index.update_version('fake-key-with-blobstore-id', versions_index['fake-key-with-blobstore-id'])
        }.to raise_error(
            %q{Cannot update entry `{"blobstore_id"=>"fake-blobstore-id", "version"=>4}' with a blobstore id}
          )
      end
    end
  end
end
