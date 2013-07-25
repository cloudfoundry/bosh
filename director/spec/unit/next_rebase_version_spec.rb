require 'spec_helper'

describe Bosh::Director::NextRebaseVersion do
  let(:versionable) { Struct.new(:version) }
  let(:existing_versions) { [] }
  let(:next_version) { Bosh::Director::NextRebaseVersion.new(existing_versions) }

  it 'leaves final versions alone' do
    expect(Bosh::Director::NextRebaseVersion.new([]).calculate('9.1')).to eq '9.1'
  end

  context 'with existing versions that have the same major version as the current version' do
    let(:existing_versions) { [versionable.new('10.1-dev'), versionable.new('10.2-dev'), versionable.new('11.1-dev')] }

    it 'finds the next version that has not already been used' do
      expect(next_version.calculate('10.1-dev')).to eq '10.3-dev'
      expect(next_version.calculate('10.3-dev')).to eq '10.3-dev'
      expect(next_version.calculate('10.9-dev')).to eq '10.3-dev'
    end

    it 'leaves -dev as a suffix for versioning consistency' do
      expect(next_version.calculate('10.1-dev')).to end_with '-dev'
    end
  end

  context 'with existing versions that do not have the same major version as the current version' do
    let(:existing_versions) { [versionable.new('9.1'), versionable.new('9.2')] }

    it 'starts the new major version (with -dev for consistency)' do
      expect(next_version.calculate('10.9-dev')).to eq '10.1-dev'
      expect(next_version.calculate('8.5-dev')).to eq '8.1-dev'
    end
  end
end