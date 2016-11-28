require 'spec_helper'
require 'bosh/dev/gem_version'

module Bosh::Dev
  describe GemVersion do
    subject(:gem_version) { GemVersion.new('FAKE_MINOR_VERSION') }

    describe '#initialize' do
      it 'raises an ArgumentError if version number is nil' do
        expect {
          described_class.new(nil)
        }.to raise_error(ArgumentError, 'Version number must be specified.')
      end

      it 'sets #version_number' do
        expect(gem_version.version).to eq('FAKE_MINOR_VERSION')
      end
    end
  end
end
