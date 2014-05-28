require 'spec_helper'
require 'semi_semantic/version'

describe Bosh::Director::NextRebaseVersion do
  let(:next_version) { Bosh::Director::NextRebaseVersion.new(server_versions) }

  def parse(version)
    Bosh::Common::VersionNumber.parse(version)
  end

  context 'when there are no versions on the server' do
    let(:server_versions) { [] }

    it 'does not change the release or pre-release segments' do
      expect(next_version.calculate(parse('9.1'))).to eq parse('9.1')
      expect(next_version.calculate(parse('9.1-RC.1'))).to eq parse('9.1-RC.1')
    end

    it 'uses the provided release and pre-release with the default dev post-release segment' do
      expect(next_version.calculate(parse('10.9-dev'))).to eq parse('10.1-dev')
      expect(next_version.calculate(parse('8.5-dev'))).to eq parse('8.1-dev')

      expect(next_version.calculate(parse('1.0.0-RC.1+dev.10'))).to eq parse('1.0.0-RC.1+dev.1')
    end
  end

  context 'when the server has a version that matches the release and pre-release segments with no post-release segment' do
    let(:server_versions) { Bosh::Common::VersionNumber.parse_list(['9.1']) }

    it 'does not change release and pre-release segments' do
      expect(next_version.calculate(parse('9.2'))).to eq parse('9.2')
    end

    it 'uses the provided release and pre-release with a new dev post-release segment' do
      expect(next_version.calculate(parse('9+dev.9'))).to eq parse('9+dev.1')
    end
  end

  context 'when the server has a version that matches the release and pre-release segments and any post-release segment' do
    let(:server_versions) { Bosh::Common::VersionNumber.parse_list(['9.1', '9.1.1-dev']) }

    it 'does not change release and pre-release segments' do
      expect(next_version.calculate(parse('9.2'))).to eq parse('9.2')
    end

    it 'increments the latest post-release segment with the same release and pre-release segments' do
      expect(next_version.calculate(parse('9.1.8-dev'))).to eq parse('9.1.2-dev')
    end
  end

  context 'when the server does not have a version that matches the release and post-release segments' do
    let(:server_versions) { Bosh::Common::VersionNumber.parse_list(['9.1', '9.1.1-dev']) }

    it 'does not change release and pre-release segments' do
      expect(next_version.calculate(parse('9.2'))).to eq parse('9.2')
    end

    it 'uses the provided release and pre-release with a new dev post-release segment' do
      expect(next_version.calculate(parse('8.9-dev'))).to eq parse('8.1-dev')
      expect(next_version.calculate(parse('9.2.9-dev'))).to eq parse('9.2.1-dev')
    end
  end

  context 'when there are multiple final versions on the server' do
    let(:server_versions) { Bosh::Common::VersionNumber.parse_list(['9.1', '9.2']) }

    it 'does not change final versions' do
      expect(next_version.calculate(parse('9.3'))).to eq parse('9.3')
    end

    it 'supports rebasing onto older final versions' do
      expect(next_version.calculate(parse('9.1.5-dev'))).to eq parse('9.1.1-dev')
    end
  end
end
