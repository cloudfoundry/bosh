require 'spec_helper'

describe Bosh::Cli::ArchiveBuilder, 'dev build' do
  let(:archive_repository_provider) { Bosh::Cli::ArchiveRepositoryProvider.new(archive_dir, artifacts_dir, blobstore) }
  subject(:builder) { Bosh::Cli::ArchiveBuilder.new(archive_repository_provider, release_options) }

  let(:resource) do
    Bosh::Cli::Resources::Package.new(release_source.join(resource_base), release_source.path)
  end

  let(:resource_spec) do
    {
      'name' => resource_name,
      'files' => file_patterns,
      'dependencies' => resource_deps,
      'excluded_files' => excluded_file_patterns,
    }
  end

  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
  let(:release_options) do
    {
      dry_run: dry_run,
      final: final
    }
  end
  let(:dry_run) { false }
  let(:final) { false }

  let(:archive_dir) { release_source.path }
  let(:artifacts_dir) { release_source.artifacts_dir }
  let(:basedir) { nil }
  let(:tmp_dirs) { [] }

  let(:resource_name) { 'pkg' }
  let(:resource_base) { "packages/#{resource_name}" }
  let(:file_patterns) { ['*.rb'] }
  let(:resource_deps) { ['foo', 'bar'] }
  let(:excluded_file_patterns) { [] }
  let(:blobstore) { double('blobstore') }

  before do
    release_source.add_file(resource_base, 'spec', resource_spec.to_yaml)
    release_source.add_dir('blobs')
    release_source.add_dir('src')
  end

  after do
    release_source.cleanup
    tmp_dirs.each { |dir| FileUtils.rm_rf(dir) }
  end

  def open_archive(file)
    tmp_dirs << tmp_dir = Dir.mktmpdir
    Dir.chdir(tmp_dir) { `tar xfz #{file}` }
    tmp_dir
  end

  describe 'generating the resource checksum' do
    before { release_source.add_file('src', '1.rb') }

    it 'has a checksum for a generated resource' do
      artifact = builder.build(resource)
      expect(artifact.sha1).to match(/^[0-9a-f]{40}$/)
    end
  end

  describe '#build' do
    let(:file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }

    before do
      matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }
      release_source.add_file('src', 'unmatched.txt')
    end

    it 'returns a BuildArtifact' do
      expect(builder.build(resource)).to be_a(Bosh::Cli::BuildArtifact)
    end

    it 'copies the Resource files to build directory' do
      artifact = builder.build(resource)
      explosion = open_archive(artifact.tarball_path)

      expect(directory_listing(explosion)).to contain_exactly(*matched_files)
      resource.files.each do |tuple|
        path = tuple[1]
        expect(File.read(File.join(explosion, path))).to eq("contents of #{path}")
      end
    end

    describe 'validation' do
      it 'validates resource' do
        validation_error = RuntimeError.new('fake-validation-error')
        allow(resource).to receive(:validate!).and_raise(validation_error)
        expect {
          builder.build(resource)
        }.to raise_error(validation_error)
      end

      context 'when validation fails because of missing license' do
        before { allow(resource).to receive(:validate!).and_raise(Bosh::Cli::MissingLicense.new('missing-license-message')) }

        it 'prints a warning' do
          allow(builder).to receive(:say)
          expect(builder).to receive(:say).with('Warning: missing-license-message')
          expect {
            builder.build(resource)
          }.to_not raise_error
        end
      end
    end

    context 'when the Resource is a Package' do
      it 'generates a tarball' do
        artifact = builder.build(resource)
        expect(release_source).to have_artifact(artifact.sha1)
      end
    end

    context 'when in dry run mode' do
      let(:dry_run) { true }

      it 'writes no tarballs' do
        expect { builder.build(resource) }.not_to change { directory_listing(archive_dir) }
      end

      it 'does not upload the tarball' do
        expect(blobstore).to_not receive(:create)
        builder.build(resource)
      end

      context 'when final' do
        let(:final) { true }

        it 'writes no tarballs' do
          expect { builder.build(resource) }.not_to change { directory_listing(archive_dir) }
        end

        it 'does not upload the tarball' do
          expect(blobstore).to_not receive(:create)
          builder.build(resource)
        end
      end
    end

    context 'when building final release' do
      let(:storage_dir) { ".final_builds/packages/#{resource_name}" }
      let(:final) { true }

      before { allow(blobstore).to receive(:create).and_return('object_id') }

      it 'generates a tarball' do
        artifact = builder.build(resource)
        explosion = open_archive(artifact.tarball_path)

        expect(directory_listing(explosion)).to contain_exactly("README.2", "README.md", "lib/1.rb", "lib/2.rb")
      end

      it 'cleans staging directory' do
        builder.build(resource)
        release_source.remove_file('src', 'lib/1.rb')
        second_resource = Bosh::Cli::Resources::Package.new(
          release_source.join(resource_base),
          release_source.path
        )

        artifact = builder.build(second_resource)
        explosion = open_archive(artifact.tarball_path)
        expect(directory_listing(explosion)).to_not include('lib/1.rb')
      end

      it 'uploads the tarball' do
        expect(blobstore).to receive(:create) do |file|
          expect(file).to be_a(File)
          sha1 = Digest::SHA1.file(file.path).hexdigest
          expect(file.path).to eq(File.join(artifacts_dir, sha1))
        end
        builder.build(resource)
      end

      context 'with empty directories are matched' do
        let(:file_patterns) { ['lib/*.rb', 'README.*', 'include_me'] }
        before { release_source.add_dir('src/include_me')}

        it 'generates a tarball which includes them' do
          artifact = builder.build(resource)
          explosion = open_archive(artifact.tarball_path)

          expect(directory_listing(explosion, true)).to contain_exactly("README.2", "README.md", "include_me", "lib", "lib/1.rb", "lib/2.rb")
        end
      end
    end

    context 'when the Resource specifies a file that collides specific to BOSH packaging' do
      let(:file_patterns) { ['*.rb', 'packaging'] }

      before do
        release_source.add_files('src', ['1.rb', 'packaging'])
        release_source.add_file('packages', "#{resource_name}/packaging")
      end

      it 'raises' do
        expect {
          builder.build(resource)
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{resource_name}' has 'packaging' file which conflicts with BOSH packaging")
      end
    end

    context 'when a glob matches no files' do
      let(:file_patterns) { ['lib/*.rb', 'baz', 'bar'] }

      before do
        release_source.add_files('src', ['lib/1.rb', 'lib/2.rb', 'baz'])
      end

      it 'raises' do
        expect {
          builder.build(resource)
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{resource_name}' has a glob that resolves to an empty file list: bar")
      end
    end

    context 'when the resource contains blobs' do
      let(:file_patterns) { ['lib/*.rb', 'README.*', '**/*.tgz'] }
      let(:matched_blobs) { ['matched.tgz'] }

      before { release_source.add_files('blobs', matched_blobs) }

      it 'includes the blobs in the build' do
        artifact = builder.build(resource)
        explosion = open_archive(artifact.tarball_path)

        expect(directory_listing(explosion)).to contain_exactly(*(matched_files + matched_blobs))
      end

      context 'when blobs have the same name as files in src' do
        before do
          release_source.add_file('src', 'README.txt', 'README from src')
          release_source.add_file('blobs', 'README.txt', 'README from blobs')
        end

        it 'picks the content from src' do
          artifact = builder.build(resource)
          explosion = open_archive(artifact.tarball_path)

          expect(File.read(File.join(explosion, 'README.txt'))).to eq('README from src')
        end
      end
    end

    context 'when specifying files to exclude' do
      let(:file_patterns) { ['**/*'] }
      let(:matched_blobs) { ['matched.tgz'] }
      let(:excluded_blobs) { ['excluded.tgz'] }
      let(:excluded_src) { ['.git'] }
      let(:excluded_file_patterns) { ['.git', 'excluded.tgz', 'unmatched.txt'] }

      before do
        release_source.add_files('src', matched_files + excluded_src)
        release_source.add_files('blobs', matched_blobs + excluded_blobs)
      end

      it 'the exclusions are not found in the build directory' do
        artifact = builder.build(resource)
        explosion = open_archive(artifact.tarball_path)

        expect(directory_listing(explosion)).to contain_exactly(*(matched_files + matched_blobs))
      end
    end

    context 'when resource file points to symlink' do
      let(:file_patterns) { ['foo', 'bar'] }

      before do
        release_source.add_file('src', 'foo', 'contents of foo')
        # expose the fileutils symlink issue
        # see https://gist.github.com/mariash/3837319
        Dir.chdir(release_source.path) do
          `ln -s ./src/foo ./src/bar`
        end
      end

      it 'works' do
        artifact = builder.build(resource)
        explosion = open_archive(artifact.tarball_path)
        expect(directory_listing(explosion)).to contain_exactly('foo', 'bar')
      end
    end
  end

  describe 'the generated resource fingerprint' do
    let(:file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
    let(:reference_fingerprint) { 'f0b1b81bd6b8093f2627eaa13952a1aab8b125d1' }

    before { matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") } }

    it 'is used as the version' do
      artifact = builder.build(resource)
      expect(artifact.version).to eq(reference_fingerprint)
    end

    it 'is based on the matched files, ignoring unmatched files' do
      release_source.add_file('src', 'an-unmatched-file.txt')
      artifact = builder.build(resource)
      expect(artifact.fingerprint).to eq(reference_fingerprint)
    end

    it 'varies with the set of matched files' do
      release_source.add_file('src', 'lib/a_matched_file.rb')
      artifact = builder.build(resource)
      expect(artifact.fingerprint).to_not eq(reference_fingerprint)
    end

    it 'varies with the content of matched files' do
      release_source.add_file('src', 'lib/1.rb', 'varied contents')
      artifact = builder.build(resource)
      expect(artifact.fingerprint).to_not eq(reference_fingerprint)
    end

    context 'when a file pattern matches empty directories' do
      let(:file_patterns) { ['lib/*.rb', 'README.*', 'tmp'] }

      it 'varies' do
        release_source.add_dir('src/tmp')
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file pattern matches a dotfile' do
      before { release_source.add_file('src', 'lib/.zb.rb') }

      it 'the dotfile is included in the fingerprint' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary in order' do
      let(:resource_deps) { ['bar', 'foo'] }

      it 'does not vary' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary' do
      let(:resource_deps) { ['foo', 'bar', 'baz'] }

      it 'varies' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies are not defined' do
      let(:resource_deps) { nil }

      it 'varies' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when blobs are present' do
      let(:file_patterns) { ['lib/*.rb', 'README.*', '*.tgz'] }
      before { release_source.add_file('blobs', 'matched.tgz') }

      it 'varies' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file comes from blobs instead of src' do
      before { FileUtils.mv(release_source.join('src', 'README.md'), release_source.join('blobs', 'README.md')) }

      it 'does not vary' do
        artifact = builder.build(resource)
        expect(artifact.fingerprint).to eq(reference_fingerprint)
      end
    end
  end

  describe 'pre_packaging script' do
    let(:temp_file) { Tempfile.new('pre_packaging.out') }
    before { release_source.add_file('src', '2.rb') }
    after { temp_file.unlink }

    it 'is executed as part of the build' do
      release_source.add_file('packages', "#{resource_name}/pre_packaging",
        "echo 'Luke I am your father.' > #{temp_file.path}; exit 0")

      builder.build(resource)
      expect(temp_file.read).to eq("Luke I am your father.\n")
    end

    context 'if the script exits with non-zero' do
      it 'causes the builder to raise' do
        release_source.add_file('packages', "#{resource_name}/pre_packaging", 'exit 1')

        expect {
          builder.build(resource)
        }.to raise_error(Bosh::Cli::InvalidPackage, "'#{resource_name}' pre-packaging failed")
      end
    end
  end

  describe 'using pre-built versions' do
    let(:file_patterns) { ['foo/**/*', 'baz'] }
    let(:fingerprint) { 'fake-fingerprint' }
    let(:final_storage_dir) { ".final_builds/packages/#{resource_name}" }
    let(:dev_storage_dir) { ".dev_builds/packages/#{resource_name}" }

    before do
      release_source.add_files('src', ['foo/foo.rb', 'foo/lib/1.rb', 'foo/lib/2.rb', 'foo/README', 'baz'])
    end

    before { allow(Bosh::Cli::BuildArtifact).to receive(:checksum).and_return(build['sha1']) }
    let(:build) { {} }

    context 'when a final version is available locally' do
      let(:build) do
        release_source.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'})
      end

      it 'should use the cached version' do
        artifact = builder.build(resource)
        expect(artifact.tarball_path).to eq(release_source.artifact_path(build['sha1']))
      end
    end

    context 'when a dev version is available locally' do
      let(:build) do
        release_source.add_version(fingerprint, dev_storage_dir, 'dev_payload', {'version' => fingerprint})
      end

      it 'should use the cached version' do
        artifact = builder.build(resource)
        expect(artifact.tarball_path).to eq(release_source.artifact_path(build['sha1']))
      end

      context 'and a final version is also available locally' do
        let(:build) do
          release_source.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'})
        end

        it 'should use the cached version' do
          artifact = builder.build(resource)
          expect(artifact.tarball_path).to eq(release_source.artifact_path(build['sha1']))
        end
      end
    end

    context 'when a final or dev version is not available locally' do
      before { allow(Bosh::Cli::BuildArtifact).to receive(:checksum).and_return('fake-sha1') }

      it 'generates a tarball and saves it in artifacts path' do
        artifact = builder.build(resource)
        expect(artifact.tarball_path).to eq(release_source.artifact_path('fake-sha1'))
      end
    end
  end
end
