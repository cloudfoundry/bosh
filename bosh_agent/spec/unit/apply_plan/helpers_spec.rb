require 'spec_helper'

describe Bosh::Agent::ApplyPlan::Helpers do
  class HelperTester
    include Bosh::Agent::ApplyPlan::Helpers

    def initialize(spec)
      validate_spec(spec)
      @install_path = '/tmp/packages/2/foo'
      @link_path    = '/tmp/packages/latest/bar'
      @blobstore_id = 'baz'
      @checksum     = 'quux'
    end

    def test_fetch_bits
      fetch_bits
    end
  end

  subject { HelperTester.new(spec) }
  let(:spec) do
    Hash['name', 'postgres',
         'version', '2',
         'sha1', 'badcafe',
         'blobstore_id', 'beefdad']
  end

  describe '#validate_spec' do
    context 'valid spec' do
      it 'does not raise an error' do
        expect { subject }.to_not raise_error
      end
    end

    context 'when spec is not a Hash' do
      let(:spec) { 'foo' }
      it 'raises an error' do
        expect { subject }.to raise_error ArgumentError, 'Invalid HelperTester spec: Hash expected, String given'
      end
    end

    context 'when required keys are missing from spec' do
      let(:spec) { {} }
      it 'raises an error' do
        expect { subject }.to raise_error ArgumentError, 'Invalid HelperTester spec: ' +
            'name, version, sha1, blobstore_id missing'
      end
    end

    context 'when required values are missing from spec' do
      let(:spec) { Hash['name', nil, 'version', nil, 'sha1', nil, 'blobstore_id', nil] }
      it 'raises an error' do
        expect { subject }.to raise_error ArgumentError, 'Invalid HelperTester spec: ' +
            'name, version, sha1, blobstore_id missing'
      end
    end
  end

  describe '#fetch_bits' do
    it 'executes the correct commands' do
      FileUtils.should_receive(:mkdir_p).with('/tmp/packages/2')
      FileUtils.should_receive(:mkdir_p).with('/tmp/packages/latest')
      Bosh::Agent::Util.should_receive(:unpack_blob).with('baz', 'quux', '/tmp/packages/2/foo')
      Bosh::Agent::Util.should_receive(:create_symlink).with('/tmp/packages/2/foo', '/tmp/packages/latest/bar')

      subject.test_fetch_bits
    end
  end

end