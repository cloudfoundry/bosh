require 'spec_helper'

module Bosh::Cli::Versions
  describe LocalArtifactStorage do
    let(:storage) { LocalArtifactStorage.new(storage_dir) }
    let(:storage_dir) { Dir.mktmpdir }
    let(:index_file) { File.join(storage_dir, 'index.yml') }

    after { FileUtils.rm_rf(storage_dir) }

    describe '#put_file' do
      let(:src_dir) { Dir.mktmpdir }
      let(:versions) do
        [
          { 'sha' => 1, 'payload_path' => 'fake-src-file-1.tgz' },
          { 'sha' => 2, 'payload_path' => 'fake-src-file-2.tgz' },
        ]
      end
      let(:src_files) { versions.map { |sha| File.join(src_dir, sha['payload_path']) } }

      after { FileUtils.rm_rf(src_dir) }

      context 'when source files exist' do
        before do
          src_files.each do |src_file_path|
            File.open(src_file_path, 'w') {|f| f.write('fake-src-bits') }
          end
        end

        it 'copies the payload into the storage dir, named by sha, and returns the new path' do
          dest_path_1 = storage.put_file('fake-sha-1', src_files[0])
          dest_path_2 = storage.put_file('fake-sha-2', src_files[1])

          expect(storage.has_file?('fake-sha-1')).to be(true)
          expect(storage.has_file?('fake-sha-2')).to be(true)
          expect(storage.has_file?('fake-sha1')).to be(false)

          expect(dest_path_1).to eq(File.join(storage_dir, 'fake-sha-1'))
          expect(dest_path_2).to eq(File.join(storage_dir, 'fake-sha-2'))

          expect(File.exist?(dest_path_1)).to be(true)
          expect(File.exist?(dest_path_2)).to be(true)
        end

        it 'creates artifacts directory' do
          FileUtils.rm_rf(storage_dir)
          dest_path = storage.put_file('fake-sha-1', src_files[0])
          expect(dest_path).to eq(File.join(storage_dir, 'fake-sha-1'))
        end
      end

      context 'when source file does not exist' do
        it 'raises an error' do
          expect {
            storage.put_file('fake-sha', src_files[0])
          }.to raise_error("Trying to store non-existant file '#{src_files[0]}' with sha 'fake-sha'")
        end
      end
    end

    describe '#get_file' do
      context 'when files exists in storage' do
        before { File.open(storage.file_path('fake-sha'), 'w') {|f| f.write('fake-stored-bits') } }

        it 'returns the local file path' do
          file_path = storage.get_file('fake-sha')
          expect(file_path).to eq(storage.file_path('fake-sha'))
        end
      end

      context 'when files does not exist in storage' do
        it 'raises an error' do
          expected_file_path = storage.file_path('fake-sha')
          expect {
            storage.get_file('fake-sha')
          }.to raise_error("Trying to retrieve non-existant file '#{expected_file_path}' with sha 'fake-sha'")
        end
      end
    end

    describe '#file_path' do
      let(:storage) { LocalArtifactStorage.new(storage_dir) }

      it 'returns the path to the payload in the storage dir' do
        expect(storage.file_path('fake-sha')).to eq(File.join(storage_dir, 'fake-sha'))
      end
    end

    describe '#has_file?' do
      it 'checks for existence of the payload in the storage dir' do
        expect(storage.has_file?('fake-sha')).to eq(false)

        payload_path = storage.file_path('fake-sha')
        File.open(payload_path, 'w') {|f| f.write('fake payload bits') }

        expect(storage.has_file?('fake-sha')).to eq(true)
      end
    end
  end
end
