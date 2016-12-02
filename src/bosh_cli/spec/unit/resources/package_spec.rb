require 'spec_helper'

describe Bosh::Cli::Resources::Package, 'dev build' do
  subject(:package) do
    Bosh::Cli::Resources::Package.new(release_source.join(base), release_source.path)
  end

  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
  let(:base) { 'packages/package_one' }
  let(:name) { 'package_one' }
  let(:spec) do
    {
      'name' => name,
      'files' => spec_files,
      'excluded_files' => spec_excluded_files,
    }
  end
  let(:spec_files) { ['**/*.rb'] }
  let(:spec_excluded_files) { [] }

  before do
    release_source.add_file(base, 'spec', spec.to_yaml)
  end

  after do
    release_source.cleanup
  end

  describe '.discover' do
    before do
      release_source.add_dir(base)
      release_source.add_dir('packages/package_two')
    end

    it 'returns an Array of Package instances' do
      packages = Bosh::Cli::Resources::Package.discover(release_source.path)
      expect(packages).to be_a(Array)
      expect(packages[0]).to be_a(Bosh::Cli::Resources::Package)
      expect(packages[1]).to be_a(Bosh::Cli::Resources::Package)
    end

    it 'ignores non-directories' do
      release_source.add_file('packages', 'ignore-me')
      expect { Bosh::Cli::Resources::Package.discover(release_source.path) }.to_not raise_error
    end
  end

  describe '#initialize' do
    it 'sets the Package base directory' do
      expect(package.package_base).to be_a(Pathname)
      expect(package.package_base.to_s).to eq(release_source.join(base))
    end

    it 'sets the Package name' do
      expect(package.name).to eq('package_one')
    end
  end

  describe '#spec' do
    it 'matches the Package spec file' do
      expect(package.spec).to eq(spec)
    end

    context 'when the spec file is missing' do
      before do
        release_source.remove_file(base, 'spec')
      end

      it 'raises' do
        expect { package.spec }.to raise_error(Bosh::Cli::InvalidPackage, 'Package spec is missing')
      end
    end
  end

  describe '#validate!' do
    context 'when the Package name does not match the Package directory name' do
      let(:name) { 'mismatch' }

      it 'raises' do
        expect { package.validate! }.to raise_error(Bosh::Cli::InvalidPackage,
            "Found '#{name}' package in '#{File.basename(base)}' directory, please fix it")
      end
    end

    context 'when the Package name is not a valid BOSH identifier' do
      let(:base) { 'packages/has space' }
      let(:name) { 'has space' }

      it 'raises' do
        expect { package.validate! }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package name, '#{name}', should be a valid BOSH identifier")
      end
    end

    context 'when the Package spec :files is missing' do
      let(:spec) do
        spec = {
          'name' => name
        }
      end

      it 'raises' do
        expect { package.validate! }.to raise_error(Bosh::Cli::InvalidPackage,
          "Package '#{name}' doesn't include any files")
      end
    end

    context 'when the Package spec :files is empty' do
      let(:spec) do
        spec = {
          'name' => name,
          'files' => []
        }
      end

      it 'raises' do
        expect { package.validate! }.to raise_error(Bosh::Cli::InvalidPackage,
          "Package '#{name}' doesn't include any files")
      end
    end

    context 'when the Package spec :files specifies files that are not found' do
      let(:spec_files) { ['**/*.rb', 'README'] }
      let(:src_files) { ['lib/one.rb', 'lib/two.rb'] }

      before do
        src_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }
      end

      it 'raises' do
        expect { package.validate! }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{name}' has a glob that resolves to an empty file list: README")
      end
    end
  end

  describe '#files' do
    context 'when matching files are found in src' do
      let(:spec_files) { ['**/*.rb'] }
      let(:src_files) { ['lib/one.rb', 'lib/two.rb'] }

      before do
        src_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }
      end

      it 'resolves the files' do
        expect(package.files.map { |entry| entry[1] }).to contain_exactly(*src_files)
      end

      it 'ignores unmatched files' do
        release_source.add_file('src', 'an-unmatched-file.txt')
        expect(package.files.map { |entry| entry[1] }).to contain_exactly(*src_files)
      end
    end

    context 'when matching files are found in src and blobs' do
      let(:spec_files) { ['**/*.rb', '**/*.tgz'] }
      let(:src_files) { ['lib/one.rb', 'lib/archive.tgz'] }
      let(:blob_files) { ['lib/archive.tgz', 'lib/other.tgz'] }

      before do
        src_files.each { |f| release_source.add_file('src', f) }
        blob_files.each { |f| release_source.add_file('blobs', f) }
      end

      it 'resolves the files, giving preference to the src directory matches' do
        expect(package.files.map { |entry| entry[1] }).to contain_exactly(*(src_files + ['lib/other.tgz']))
      end
    end

    context 'when the spec excludes matching files' do
      let(:spec_files) { ['**/*.rb', '**/*.tgz'] }
      let(:src_files) { ['lib/one.rb', 'lib/archive.tgz', 'lib/excluded.tgz'] }
      let(:spec_excluded_files) { ['lib/excluded.tgz'] }

      before do
        src_files.each { |f| release_source.add_file('src', f) }
      end

      it 'does not include the exclusions' do
        expect(package.files.map { |entry| entry[1] }).to contain_exactly(*(src_files - spec_excluded_files))
      end
    end
  end
end
