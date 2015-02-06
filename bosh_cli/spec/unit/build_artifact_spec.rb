require 'spec_helper'

describe Bosh::Cli::BuildArtifact, 'dev build' do
  subject(:artifact) { Bosh::Cli::BuildArtifact.new('package_one', artifact_metadata, 'fingerprint', tarball_path, 'sha1', nil, true) }

  let(:artifact_metadata) do
    {
      'name' => 'package_one',
    }
  end

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
  let(:tarball_path) { 'path/to/archive.tgz' }
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

  describe '.make_fingerprint' do
    let(:resource_spec) do
      {
        'name' => 'package_one',
        'files' => ['lib/*.rb', 'README.*'],
        'dependencies' => ['foo', 'bar'],
      }
    end
    subject(:fingerprint) { Bosh::Cli::BuildArtifact.make_fingerprint(resource) }

    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
    let(:reference_fingerprint) { 'f0b1b81bd6b8093f2627eaa13952a1aab8b125d1' }

    it 'is based on the matched files' do
      expect(fingerprint).to eq(reference_fingerprint)
    end

    it 'ignores unmatched files' do
      release_dir.add_file('src', 'an-unmatched-file.txt')
      expect(fingerprint).to eq(reference_fingerprint)
    end

    it 'varies with the set of matched files' do
      release_dir.add_file('src', 'lib/a_matched_file.rb')
      expect(fingerprint).to_not eq(reference_fingerprint)
    end

    it 'varies with the content of matched files' do
      release_dir.add_file('src', 'lib/1.rb', 'varied contents')
      expect(fingerprint).to_not eq(reference_fingerprint)
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
        expect(fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file pattern matches a dotfile' do
      before { release_dir.add_file('src', 'lib/.zb.rb') }

      it 'the dotfile is included in the fingerprint' do
        expect(fingerprint).to_not eq(reference_fingerprint)
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
        expect(fingerprint).to eq(reference_fingerprint)
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
        expect(fingerprint).to_not eq(reference_fingerprint)
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

      it 'varies' do
        expect(fingerprint).to_not eq(reference_fingerprint)
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
        expect(fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file comes from blobs instead of src' do
      before do
        release_dir.add_dir('blobs')
        FileUtils.mv(release_dir.join('src', 'README.md'), release_dir.join('blobs', 'README.md'))
      end

      it 'does not vary' do
        expect(fingerprint).to eq(reference_fingerprint)
      end
    end
  end

  describe '#version' do
    it 'matches the fingerprint' do
      expect(artifact.version).to eq(artifact.fingerprint)
    end
  end
end
