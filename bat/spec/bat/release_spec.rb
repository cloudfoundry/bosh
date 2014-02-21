require 'spec_helper'
require 'bat/release'
require 'fileutils'

describe Bat::Release do
  subject(:release) { Bat::Release.new(release_name, release_versions) }
  let(:release_name) { 'FAKE_NAME' }
  let(:release_versions) { %w(FAKE_VERSION_1 FAKE_VERSION_2) }

  describe '.from_path' do
    include FakeFS::SpecHelpers

    let(:bat_path) { '/fake/bat/path' }

    context 'when there files in the path' do
      before do
        bat_releases_dir = File.join(bat_path, 'releases')
        FileUtils.mkdir_p(bat_releases_dir)

        deployment_file = File.join(bat_releases_dir, 'bat-0.yml')
        File.open(deployment_file, 'w') { |f| f.write("CONTENT: #{deployment_file}") }

        deployment_file = File.join(bat_releases_dir, 'bat-1.yml')
        File.open(deployment_file, 'w') { |f| f.write("CONTENT: #{deployment_file}") }

        deployment_file = File.join(bat_releases_dir, 'bat-12.yml')
        File.open(deployment_file, 'w') { |f| f.write("CONTENT: #{deployment_file}") }
      end

      before do
        bat_dev_releases_dir = File.join(bat_path, 'dev_releases')
        FileUtils.mkdir_p(bat_dev_releases_dir)

        deployment_file = File.join(bat_dev_releases_dir, 'bat-1.1-dev.yml')
        File.open(deployment_file, 'w') { |f| f.write("CONTENT: #{deployment_file}") }
      end

      it 'creates a Release named "bat" with versions found in the path specified' do
        release = Bat::Release.from_path(bat_path)
        expect(release.name).to eq('bat')
        expect(release.sorted_versions).to eq(%w(0 1 1.1-dev 12))
        expect(release.path).to eq(bat_path)
      end
    end

    context 'when there are no files in the path' do
      before { FileUtils.rm_f(bat_path, force: true) }

      it 'raises an error' do
        expect {
          Bat::Release.from_path(bat_path)
        }.to raise_error(RuntimeError, /no final or dev releases.*#{bat_path}/)
      end
    end
  end

  describe '#initialize' do
    it 'sets name' do
      expect(Bat::Release.new('NAME', nil).name).to eq('NAME')
    end

    it 'sets versions' do
      expect(Bat::Release.new(nil, %w(0 1)).sorted_versions).to eq(%w(0 1))
    end

    it 'sets path to nil' do
      expect(Bat::Release.new('NOT_PATH', []).path).to eq(nil)
    end

    context 'when a third argument is passed' do
      it 'sets path' do
        expect(Bat::Release.new(nil, nil, '/fake/path').path).to eq('/fake/path')
      end
    end
  end

  describe '#to_s' do
    it 'returns "name-version"' do
      expect(release.to_s).to eq('FAKE_NAME-FAKE_VERSION_2')
    end
  end

  describe '#to_path' do
    it 'raises an exception (even though it should not)' do
      expect { release.to_path }.to raise_error
    end

    context 'when path is specified' do
      subject(:release) { Bat::Release.new('FAKE_NAME', release_versions, '/fake/path') }

      it 'returns its #path, and #to_s values joined as a YAML file path' do
        expect(release.to_path).to eq('/fake/path/releases/FAKE_NAME-FAKE_VERSION_2.yml')
      end
    end
  end

  describe '#version' do
    let(:release_versions) { %w(FAKE_VERSION_11 FAKE_VERSION_33 FAKE_VERSION_66 FAKE_VERSION_99).shuffle }

    it 'retuns the last element in the versions array' do
      expect(release.version).to eq(release_versions.last)
    end
  end

  describe '#latest' do
    let(:release_versions) { %w(FAKE_VERSION_11 FAKE_VERSION_33 FAKE_VERSION_66 FAKE_VERSION_99).shuffle }

    it 'retuns the last element in the versions array' do
      expect(release.latest).to eq(release_versions.last)
    end
  end

  describe '#previous' do
    subject(:release) { Bat::Release.new('FAKE_NAME', release_versions, '/fake/path') }

    it 'returns a new Bat::Release whose #versions are missing the last element' do
      previous_release = release.previous
      expect(previous_release.name).to eq('FAKE_NAME')
      expect(previous_release.sorted_versions).to eq(%w(FAKE_VERSION_1))
      expect(previous_release.path).to eq('/fake/path')
    end

    it 'does not change #versions' do
      expect { release.previous }.not_to change { release.sorted_versions }
    end

    context 'when there are fewer than two versions' do
      let(:release_versions) { %w(FAKE_VERSION_0) }

      it 'raises an error' do
        expect { release.previous }.to raise_error(RuntimeError, /no previous version/)
      end
    end
  end

  describe '#==' do
    it 'returns true if the other object is a Release with the same #name and any common #versions' do
      equal_release = Bat::Release.new(release_name, release_versions.sample(1))
      expect(release == equal_release).to be(true)
    end
  end
end
