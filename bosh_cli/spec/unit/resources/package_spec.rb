require 'spec_helper'

describe Bosh::Cli::Resources::Package, 'dev build' do
  subject(:package) do
    spec = {
      'name' => package_name,
      'files' => file_patterns,
      'dependencies' => package_deps,
      'excluded_files' => excluded_file_patterns,
    }

    Bosh::Cli::Resources::Package.new(spec, release_source.path, final, blobstore)
  end
  let(:package_name) { 'pkg' }
  let(:file_patterns) { ['*.rb'] }
  let(:package_deps) { ['foo', 'bar'] }
  let(:excluded_file_patterns) { [] }

  # ???
  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
  let(:final) { false }
  let(:blobstore) { double('blobstore') }

  after do
    release_source.cleanup
  end

  describe 'initialization of a new Package' do
    it 'sets the package name' do
      expect(package.name).to eql(package_name)
    end

    it 'sets the package globs' do
      expect(package.globs).to eql(file_patterns)
    end

    context 'when name is missing' do
      let(:package_name) { ' ' }

      it 'raises' do
        expect { package }.to raise_error(Bosh::Cli::InvalidPackage, 'Package name is missing')
      end
    end

    context 'when name has funny characters' do
      let(:package_name) { '@#!' }

      it 'raises' do
        expect { package }.to raise_error(Bosh::Cli::InvalidPackage, "Package name, '@#!', should be a valid BOSH identifier")
      end
    end

    context 'when no package files are specified' do
      let(:file_patterns) { [] }

      it 'raises' do
        expect { package }.to raise_error(Bosh::Cli::InvalidPackage, "Package '#{package_name}' doesn't include any files")
      end
    end
  end

  describe 'file matching' do
    let(:file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }

    before do
      matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }
    end

    it 'resolves to matched files' do
      expect(package.files.map { |entry| entry[1] }).to contain_exactly(*matched_files)
    end

    it 'ignores unmatched files' do
      release_source.add_file('src', 'an-unmatched-file.txt')
      expect(package.files.map { |entry| entry[1] }).to contain_exactly(*matched_files)
    end
  end
end
