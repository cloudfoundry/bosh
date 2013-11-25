require 'spec_helper'

require 'bat/release'
require 'fileutils'

describe Bat::Release do
  let(:release_name) { 'FAKE_NAME' }
  let(:release_versions) { %w(FAKE_VERSION_1 FAKE_VERSION_2) }

  subject(:release) { Bat::Release.new(release_name, release_versions) }

  describe '.from_path' do
    include FakeFS::SpecHelpers

    let(:bat_path) { '/fake/bat/path' }

    before do
      bat_releases_dir = File.join(bat_path, 'releases')
      FileUtils.mkdir_p(bat_releases_dir)

      2.times do |index|
        deployment_file = File.join(bat_releases_dir, "bat-VER#{index}.yml")

        File.open(deployment_file, 'w') { |f| f.write("CONTENT: #{deployment_file}") }
      end
    end

    it 'creates a Release named "bat" with versions found in the path specified' do
      release = Bat::Release.from_path(bat_path)

      expect(release.name).to eq('bat')
      expect(release.versions).to eq(%w(VER0 VER1))
      expect(release.path).to eq(bat_path)
    end

    context 'when there are no files in the path' do
      before do
        FileUtils.rm_f(bat_path)
      end

      it 'raises an error' do
        expect {
          Bat::Release.from_path(bat_path)
        }.to raise_error(RuntimeError, "no matches for #{bat_path}/releases/bat-*.yml")
      end
    end
  end

  describe '#initialize' do
    it 'sets name' do
      expect(Bat::Release.new('NAME', nil).name).to eq('NAME')
    end

    it 'sets versions' do
      expect(Bat::Release.new(nil, %w(FAKE_00 FAKE_01)).versions).to eq(%w(FAKE_00 FAKE_01))
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
      expect(previous_release.versions).to eq(%w(FAKE_VERSION_1))
      expect(previous_release.path).to eq('/fake/path')
    end

    it 'does not change #versions' do
      expect { release.previous }.not_to change { release.versions }
    end

    context 'when there are fewer than two versions' do
      let(:release_versions) { %w(FAKE_VERSION_0) }

      it 'raises an error' do
        expect { release.previous }.to raise_error(RuntimeError, 'no previous version')
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
