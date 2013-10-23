require 'spec_helper'
require 'bosh/deployer/hash_fingerprinter'

describe Bosh::Deployer::HashFingerprinter do
  describe '#sha1' do
    subject(:hash_fingerprinter) { described_class.new }

    it 'returns same sha1 for same hashes' do
      expect_to_be_sha1(result1 = subject.sha1('key' => 'value'))
      expect_to_be_sha1(result2 = subject.sha1('key' => 'value'))
      expect(result1).to eq(result2)
    end

    it 'returns same sha1 for a hashes that contain same nested hashes' do
      expect_to_be_sha1(result1 = subject.sha1('key' => { 'nested-key' => 'value' }))
      expect_to_be_sha1(result2 = subject.sha1('key' => { 'nested-key' => 'value' }))
      expect(result1).to eq(result2)
    end

    it 'returns a different sha1 for two hashes that have different keys' do
      expect_to_be_sha1(result1 = subject.sha1('key' => 'value'))
      expect_to_be_sha1(result2 = subject.sha1('key-different' => 'value'))
      expect(result1).to_not eq(result2)
    end

    it 'returns a different sha1 for two hashes that have different values' do
      expect_to_be_sha1(result1 = subject.sha1('key' => 'value'))
      expect_to_be_sha1(result2 = subject.sha1('key' => 'value-different'))
      expect(result1).to_not eq(result2)
    end

    it 'returns same sha1 for hashes that have same keys in different order' do
      expect_to_be_sha1(result1 = subject.sha1('key1' => 'value1', 'key2' => 'value2'))
      expect_to_be_sha1(result2 = subject.sha1('key2' => 'value2', 'key1' => 'value1'))
      expect(result1).to eq(result2)
    end

    it 'returns same sha1 for hashes with nested hashes that have same keys in different order' do
      result1 = subject.sha1('key' => { 'nested-key1' => 'value1', 'nested-key2' => 'value2' })
      expect_to_be_sha1(result1)

      result2 = subject.sha1('key' => { 'nested-key2' => 'value2', 'nested-key1' => 'value1' })
      expect_to_be_sha1(result1)

      expect(result1).to eq(result2)
    end

    def expect_to_be_sha1(result)
      expect(result).to be_a(String)
      expect(result).to_not be_empty
    end
  end
end
