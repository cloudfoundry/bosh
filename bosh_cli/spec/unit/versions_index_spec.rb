require 'spec_helper'

module Bosh::Cli
  describe VersionsIndex do
    let(:versions_index) { VersionsIndex.new(tmp_dir) }
    let(:tmp_dir) { Dir.mktmpdir }
    let(:index_file) { File.join(tmp_dir, 'index.yml') }
  
    after { FileUtils.rm_rf(tmp_dir) }

    describe '#initialize' do
      it 'errors if the index file is malformed' do
        File.open(index_file, 'w') { |f| f.write('fake index file') }

        expect {
          versions_index = VersionsIndex.new(tmp_dir)
        }.to raise_error(InvalidIndex, 'Invalid versions index data type, String given, Hash expected')
      end

      it 'allows index file to be empty' do
        File.open(index_file, 'w') { |f| f.write('') }

        versions_index = Bosh::Cli::VersionsIndex.new(tmp_dir)
        expect(versions_index.version_strings).to be_empty
      end
    end

    describe '#add_version' do
      it 'lazily creates index file when a version has been added' do
        expect(File).to_not exist(index_file)

        versions_index.add_version('fake-key', { 'version' => 2 })
        expect(File).to exist(index_file)
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
          InvalidIndex, "Cannot save index entry without a version: `#{build_without_version}'"
        )
      end

      it 'does not allow duplicate versions with different keys' do
        item1 = { 'version' => '1.9-dev' }

        versions_index.add_version('fake-key-1', item1)

        expect {
          versions_index.add_version('fake-key-2', item1)
        }.to raise_error(
          "Trying to add duplicate version `1.9-dev' into index `#{File.join(tmp_dir, 'index.yml')}'"
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

    context 'after versions have been added' do
      let(:builds) do
        {
          'fake-key-1' => { 'a' => 1, 'b' => 2, 'version' => 1 },
          'fake-key-2' => { 'a' => 3, 'b' => 4, 'version' => 2 },
          'fake-key-3' => { 'a' => 5, 'b' => 6, 'version' => 3 },
        }
      end

      before { builds.each{ |k, v| versions_index.add_version(k, v) } }

      describe '#each_pair' do
        it 'executes the block on each hash entry' do
          versions_index.each_pair { |k, v| expect(v).to eq(builds[k]) }
        end
      end

      describe '#select' do
        it 'executes the block on each hash entry' do
          selected = versions_index.select { |k, v| v['version'] > 1 }
          expected = builds.select { |k, v| v['version'] > 1 }

          expect(selected).to eq(expected)
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

  end
end
