require 'spec_helper'
require 'bosh/dev/gem_version'

module Bosh::Dev
  describe GemVersion do
    subject(:gem_version) { GemVersion.new('FAKE_MINOR_VERSION') }

    describe '#initialize' do
      it 'raises an ArgumentError if minor_version_number is nil' do
        expect {
          described_class.new(nil)
        }.to raise_error(ArgumentError, 'Minor version number must be specified.')
      end

      it 'sets #version_number' do
        expect(gem_version.minor_version_number).to eq('FAKE_MINOR_VERSION')
      end
    end

    describe '#version' do
      it 'builds gem version number from major version, build number, and patch level' do
        expect(gem_version.version).to eq('1.FAKE_MINOR_VERSION.0')
      end
    end
  end
end
