require 'spec_helper'

describe Bosh::Cli::BuildArtifact, 'dev build' do
  subject(:artifact) { Bosh::Cli::BuildArtifact.new(resource) }

  let(:release_dir) { Support::FileHelpers::ReleaseDirectory.new }
  # let(:storage_dir) { Support::FileHelpers::ReleaseDirectory.new }
  # let(:staging_dir) { Support::FileHelpers::ReleaseDirectory.new }

  let(:resource) { Bosh::Cli::Resources::Package.new(release_dir.join(resource_path), release_dir.path) }
  let(:resource_path) { 'packages/package_one' }
  let(:resource_spec) do
    {
      'name' => 'package_one',
      'files' => ['**/*.rb'],
    }
  end
  let(:matched_files) { ['lib/1.rb', 'lib/2.rb'] }

  before do
    release_dir.add_file(resource_path, 'spec', resource_spec.to_yaml)
    matched_files.each { |file| release_dir.add_file('src', file, "contents of #{file}") }
  end

  after do
    release_dir.cleanup
  end

  describe '#name' do
    it 'matches the Resource name' do
      expect(artifact.name).to eq(resource.name)
    end
  end

  describe '#metadata' do
    let(:metadata) { artifact.metadata }

    it 'includes metadata provided by the Resource' do
      resource.metadata.each do |key, value|
        expect(metadata[key]).to eq(value)
      end
    end

    it 'includes fingerprint' do
      expect(metadata['fingerprint']).to eq(artifact.fingerprint)
    end

    it 'includes checksum' do
      value = 'checksum'
      artifact.checksum = value
      expect(metadata['sha1']).to eq(value)
    end

    it 'includes version' do
      expect(metadata['version']).to eq(artifact.version)
    end

    it 'includes new_version' do
      value = true
      artifact.new_version = value
      expect(metadata['new_version']).to eq(value)
    end

    it 'includes notes' do
      value = 'some notes'
      artifact.notes = value
      expect(metadata['notes']).to eq(value)
    end

    it 'includes tarball_path' do
      value = 'path/to/archive.tgz'
      artifact.tarball_path = value
      expect(metadata['tarball_path']).to eq(value)
    end
  end

  describe '#fingerprint' do
    let(:resource_spec) do
      {
        'name' => 'package_one',
        'files' => ['lib/*.rb', 'README.*'],
        'dependencies' => ['foo', 'bar'],
      }
    end

    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
    let(:reference_fingerprint) { 'f0b1b81bd6b8093f2627eaa13952a1aab8b125d1' }

    it 'is based on the matched files' do
      expect(artifact.fingerprint).to eq(reference_fingerprint)
    end

    it 'ignores unmatched files' do
      release_dir.add_file('src', 'an-unmatched-file.txt')
      expect(artifact.fingerprint).to eq(reference_fingerprint)
    end

    it 'varies with the set of matched files' do
      release_dir.add_file('src', 'lib/a_matched_file.rb')
      expect(artifact.fingerprint).to_not eq(reference_fingerprint)
    end

    it 'varies with the content of matched files' do
      release_dir.add_file('src', 'lib/1.rb', 'varied contents')
      expect(artifact.fingerprint).to_not eq(reference_fingerprint)
    end

    context 'when a file pattern matches empty directories' do
      let(:resource_spec) do
        {
          'name' => 'package_one',
          'files' => ['lib/*.rb', 'README.*', 'tmp'],
          'dependencies' => ['foo', 'bar'],
        }
      end

      it 'varies' do
        release_dir.add_dir('src/tmp')
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file pattern matches a dotfile' do
      before { release_dir.add_file('src', 'lib/.zb.rb') }

      it 'the dotfile is included in the fingerprint' do
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary in order' do
      let(:resource_spec) do
        {
          'name' => 'package_one',
          'files' => ['lib/*.rb', 'README.*'],
          'dependencies' => ['bar', 'foo'],
        }
      end

      it 'does not vary' do
        expect(artifact.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary' do
      let(:resource_spec) do
        {
          'name' => 'package_one',
          'files' => ['lib/*.rb', 'README.*'],
          'dependencies' => ['foo', 'bar', 'baz'],
        }
      end

      it 'varies' do
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies are not defined' do
      let(:resource_spec) do
        {
          'name' => 'package_one',
          'files' => ['lib/*.rb', 'README.*'],
          'dependencies' => nil,
        }
      end

      before do
        allow(resource).to receive(:dependencies).and_return(nil)
      end

      it 'varies' do
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when blobs are present' do
      let(:resource_spec) do
        {
          'name' => 'package_one',
          'files' => ['lib/*.rb', 'README.*', '*.tgz'],
          'dependencies' => ['foo', 'bar'],
        }
      end

      before { release_dir.add_file('blobs', 'matched.tgz') }

      it 'varies' do
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file comes from blobs instead of src' do
      before do
        release_dir.add_dir('blobs')
        FileUtils.mv(release_dir.join('src', 'README.md'), release_dir.join('blobs', 'README.md'))
      end

      it 'does not vary' do
        expect(artifact.fingerprint).to eq(reference_fingerprint)
      end
    end
  end

  describe '#version' do
    it 'matches the fingerprint' do
      expect(artifact.version).to eq(artifact.fingerprint)
    end
  end
end
