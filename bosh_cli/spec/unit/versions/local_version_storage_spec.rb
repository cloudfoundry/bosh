require 'spec_helper'

module Bosh::Cli
  describe LocalVersionStorage do
    let(:storage) { LocalVersionStorage.new(storage_dir) }
    let(:storage_dir) { Dir.mktmpdir }
    let(:index_file) { File.join(storage_dir, 'index.yml') }

    after { FileUtils.rm_rf(storage_dir) }

    describe '#put_file' do
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
            File.open(src_file_path, 'w') {|f| f.write('fake-src-bits') }
          end
        end

        it 'copies the payload into the storage dir, named by version, and returns the new path' do
          dest_path_1 = storage.put_file(1, src_files[0])
          dest_path_2 = storage.put_file(2, src_files[1])

          expect(storage.has_file?(1)).to be(true)
          expect(storage.has_file?(2)).to be(true)
          expect(storage.has_file?('fake-version')).to be(false)

          expect(dest_path_1).to eq(File.join(storage_dir, '1.tgz'))
          expect(dest_path_2).to eq(File.join(storage_dir, '2.tgz'))

          expect(File.exist?(dest_path_1)).to be(true)
          expect(File.exist?(dest_path_2)).to be(true)
        end
      end

      context 'when source file does not exist' do
        it 'raises an error' do
          expect {
            storage.put_file('fake-version', src_files[0])
          }.to raise_error("Trying to store non-existant file `#{src_files[0]}' for version `fake-version'")
        end
      end
    end

    describe '#get_file' do
      context 'when files exists in storage' do
        before { File.open(storage.file_path('fake-version'), 'w') {|f| f.write('fake-stored-bits') } }

        it 'returns the local file path' do
          file_path = storage.get_file('fake-version')
          expect(file_path).to eq(storage.file_path('fake-version'))
        end
      end

      context 'when files does not exist in storage' do
        it 'raises an error' do
          expected_file_path = storage.file_path('fake-version')
          expect {
            storage.get_file('fake-version')
          }.to raise_error("Trying to retrieve non-existant file `#{expected_file_path}' for version `fake-version'")
        end
      end
    end

    describe '#file_path' do
      context 'when a name prefix exists' do
        let(:storage) { LocalVersionStorage.new(storage_dir, 'fake-prefix') }

        it 'returns the path to the payload in the storage dir, with the prefix in the file name' do
          expect(storage.file_path('fake-version')).to eq(File.join(storage_dir, 'fake-prefix-fake-version.tgz'))
        end
      end

      context 'when no name prefix exists' do
        let(:storage) { LocalVersionStorage.new(storage_dir) }

        it 'returns the path to the payload in the storage dir' do
          expect(storage.file_path('fake-version')).to eq(File.join(storage_dir, 'fake-version.tgz'))
        end
      end
    end

    describe '#has_file?' do
      it 'checks for existence of the payload in the storage dir' do
        expect(storage.has_file?('fake-version')).to eq(false)

        payload_path = storage.file_path('fake-version')
        File.open(payload_path, 'w') {|f| f.write('fake payload bits') }

        expect(storage.has_file?('fake-version')).to eq(true)
      end
    end
  end
end
