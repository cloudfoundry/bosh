require 'spec_helper'

module Bosh::Cli
  describe CachingVersionsIndex do
    let(:caching_versions_index) { CachingVersionsIndex.new(versions_index) }
    let(:versions_index) { VersionsIndex.new(tmp_dir) }
    let(:tmp_dir) { Dir.mktmpdir }
    let(:index_file) { File.join(tmp_dir, 'index.yml') }

    after { FileUtils.rm_rf(tmp_dir) }

    describe '#add_version' do
      let(:src_dir) { Dir.mktmpdir }
      let(:versions) do
        [
          { 'version' => 1, 'payload_path' => 'fake-src-file-1.tgz' },
          { 'version' => 2, 'payload_path' => 'fake-src-file-2.tgz' },
        ]
      end
      let(:src_files) { versions.map { |version| File.join(src_dir, version['payload_path']) } }

      after { FileUtils.rm_rf(src_dir) }

      context 'when source files exist' do
        before do
          src_files.each do |src_file_path|
            File.open(src_file_path, 'w') {|f| f.write('fake src bits') }
          end
        end

        it 'delegates to VersionsIndex.add_version' do
          expect(versions_index).to receive(:add_version).with('fake-key', versions[0]).and_call_original

          caching_versions_index.add_version('fake-key', versions[0], src_files[0])
        end

        it 'copies the payload into the storage dir, named by version, and returns the new path' do
          dest_path_1 = caching_versions_index.add_version('fake-key-1', versions[0], src_files[0])
          dest_path_2 = caching_versions_index.add_version('fake-key-2', versions[1], src_files[1])

          expect(caching_versions_index['fake-key-1']).to eq(versions[0])
          expect(caching_versions_index['fake-key-2']).to eq(versions[1])

          expect(caching_versions_index.version_exists?(1)).to be(true)
          expect(caching_versions_index.version_exists?(2)).to be(true)
          expect(caching_versions_index.version_exists?(3)).to be(false)

          expect(dest_path_1).to eq(File.join(tmp_dir, '1.tgz'))
          expect(dest_path_2).to eq(File.join(tmp_dir, '2.tgz'))

          expect(File.exist?(dest_path_1)).to be(true)
          expect(File.exist?(dest_path_2)).to be(true)
        end

        it 'adds the sha1 of the payload to the version record' do
          caching_versions_index.add_version('fake-key-1', versions[0], src_files[0])

          expect(caching_versions_index['fake-key-1']['sha1']).to eq(Digest::SHA1.file(src_files[0]).hexdigest)
        end
      end

      context 'when source files do not exist' do
        it 'errors' do
          expect {
            caching_versions_index.add_version('fake-key', versions[0], src_files[0])
          }.to raise_error(/Trying to copy payload/)
        end
      end
    end

    describe '#store_file' do
      let(:index_key) { 'fake-key' }

      let(:src_dir) { Dir.mktmpdir }
      let(:src_file_path) { File.join(src_dir, 'fake-src-file.tgz') }
      before { File.open(src_file_path, 'w') { |f| f.write('fake-bits') } }

      after { FileUtils.rm_rf(src_dir) }

      context 'when version record exists' do
        context 'when the version record includes a sha1' do
          before { caching_versions_index.add_version(index_key, { 'version' => 'fake-version' }, src_file_path) }

          context 'when the sha1 of the supplied file matches the version record sha1' do
            it 'copies the provided file to the storage dir and returns the file path' do
              file_path = caching_versions_index.store_file(index_key, src_file_path)

              version = caching_versions_index[index_key]['version']
              expect(file_path).to eq(caching_versions_index.filename(version))

              expect(File).to exist(file_path)

              new_sha1 = Digest::SHA1.file(src_file_path).hexdigest
              expected_sha1 = caching_versions_index[index_key]['sha1']
              expect(new_sha1).to eq(expected_sha1)
            end
          end

          context 'when the sha1 of the supplied file does not match the version record sha1' do
            before { File.open(src_file_path, 'w') { |f| f.write('fake-corrupted-bits') } }

            it 'raises a Sha1MismatchError' do
              new_sha1 = Digest::SHA1.file(src_file_path).hexdigest
              expect {
                caching_versions_index.store_file(index_key, src_file_path)
              }.to raise_error(
                CachingVersionsIndex::Sha1MismatchError,
                "Expected sha1 '#{caching_versions_index[index_key]['sha1']}', but got sha1 '#{new_sha1}'",
              )
            end
          end
        end

        context 'when the version record does not include a sha1' do
          before { versions_index.add_version(index_key, { 'version' => 'fake-version' }) }

          it 'raises an error' do
            expect {
              caching_versions_index.store_file(index_key, src_file_path)
            }.to raise_error(
              "Trying to cache file with no sha1 in version record `#{index_key}' in index `#{versions_index.index_file}'"
            )
          end
        end
      end

      context 'when version record does not exists' do
        it 'raises an error' do
          expect {
            caching_versions_index.store_file(index_key, src_file_path)
          }.to raise_error(
            "Trying to cache file for missing version record `#{index_key}' in index `#{versions_index.index_file}'"
          )
        end
      end
    end

    describe '#filename' do
      context 'when a name prefix exists' do
        let(:caching_versions_index) { CachingVersionsIndex.new(versions_index, 'fake-prefix') }

        it 'returns the path to the payload in the storage dir, with the prefix in the file name' do
          expect(caching_versions_index.filename('fake-version')).to eq(File.join(tmp_dir, 'fake-prefix-fake-version.tgz'))
        end
      end

      context 'when no name prefix exists' do
        let(:caching_versions_index) { CachingVersionsIndex.new(versions_index) }

        it 'returns the path to the payload in the storage dir' do
          expect(caching_versions_index.filename('fake-version')).to eq(File.join(tmp_dir, 'fake-version.tgz'))
        end
      end
    end

    describe '#version_exists?' do
      it 'checks for existence of the payload in the storage dir' do
        expect(caching_versions_index.version_exists?('fake-version')).to eq(false)

        payload_path = caching_versions_index.filename('fake-version')
        File.open(payload_path, 'w') {|f| f.write('fake payload bits') }

        expect(caching_versions_index.version_exists?('fake-version')).to eq(true)
      end
    end

    describe '#set_blobstore_id' do
      context 'when version record exists' do
        let(:src_dir) { Dir.mktmpdir }
        let(:versions) { ['fake-src-file-1.tgz'] }
        let(:src_files) { versions.map { |version| File.join(src_dir, version) } }

        before do
          src_files.each do |src_file_path|
            File.open(src_file_path, 'w') {|f| f.write('fake src bits') }
          end
        end

        before do
          caching_versions_index.add_version('fake-key', { 'version' => '1' }, src_files[0])
        end

        after { FileUtils.rm_rf(src_dir) }

        it 'updates the blobstore_id' do
          expect(caching_versions_index['fake-key']['blobstore_id']).to be_nil

          caching_versions_index.set_blobstore_id('fake-key', 'fake-blobstore-id')

          expect(caching_versions_index['fake-key']['blobstore_id']).to eql('fake-blobstore-id')
        end
      end

      context 'when version record does not exists' do
        it 'errors if the version record does not exist' do
          expect{
            caching_versions_index.set_blobstore_id('fake-key', 'fake-blobstore-id')
          }.to raise_error(/Trying to set blobstore_id .* on missing version record/)
        end
      end
    end

    describe '#find_by_checksum' do
      let(:src_dir) { Dir.mktmpdir }
      let(:versions) do
        [
          { 'version' => 1, 'payload_path' => 'fake-src-file-1.tgz' },
          { 'version' => 2, 'payload_path' => 'fake-src-file-2.tgz' },
        ]
      end
      let(:src_files) { versions.map { |version| File.join(src_dir, version['payload_path']) } }

      before do
        src_files.each do |src_file_path|
          File.open(src_file_path, 'w') {|f| f.write(SecureRandom.uuid) }
        end
      end

      before do
        caching_versions_index.add_version('fake-key-1', versions[0], src_files[0])
        caching_versions_index.add_version('fake-key-2', versions[1], src_files[1])
      end

      after { FileUtils.rm_rf(src_dir) }

      context 'when a version record exists with the provided sha1' do
        it 'returns the first version record with the provided sha1' do
          checksum1 = Digest::SHA1.file(src_files[0]).hexdigest
          checksum2 = Digest::SHA1.file(src_files[1]).hexdigest

          expect(caching_versions_index.find_by_checksum(checksum1)).to eq(versions[0].merge('sha1' => checksum1))
          expect(caching_versions_index.find_by_checksum(checksum2)).to eq(versions[1].merge('sha1' => checksum2))
        end
      end

      context 'when a version record does not exist with the provided sha1' do
        it 'returns nil' do
          checksum1 = Digest::SHA1.hexdigest('some random stuff')

          expect(caching_versions_index.find_by_checksum(checksum1)).to eq(nil)
        end
      end
    end
  end
end
