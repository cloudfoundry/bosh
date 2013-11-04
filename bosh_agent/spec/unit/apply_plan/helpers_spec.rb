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
    install_path = '/tmp/packages/2/foo'

    before { Bosh::Agent::Util.stub(:unpack_blob) }
    before { FileUtils.stub(:mv) }

    context 'when unpacked blob already exists' do
      before { Dir.stub(:exist?).with(install_path).and_return(true) }

      it 'does not re-download and unpacks blob' do
        Bosh::Agent::Util.should_not_receive(:unpack_blob)
        subject.send(:fetch_bits)
      end
    end

    context 'when unpacked blob does not exist' do
      before { Dir.stub(:exist?).with(install_path).and_return(false) }

      it 'downloads and unpacks blob into install path' do
        Bosh::Agent::Util.should_receive(:unpack_blob).with('baz', 'quux', install_path)
        subject.send(:fetch_bits)
      end
    end
  end

  describe '#fetch_bits_and_symlink' do
    install_path = '/tmp/packages/2/foo'
    link_path = '/tmp/packages/latest/bar'

    before { Bosh::Agent::Util.stub(:unpack_blob) }
    before { Bosh::Agent::Util.stub(:create_symlink) }
    before { FileUtils.stub(:mv) }

    context 'when unpacked blob already exists' do
      before { Dir.stub(:exist?).with(install_path).and_return(true) }

      it 'does not re-download and unpacks blob' do
        Bosh::Agent::Util.should_not_receive(:unpack_blob)
        subject.send(:fetch_bits_and_symlink)
      end

      it 'relinks unpacked blob to install path' do
        Bosh::Agent::Util.should_receive(:create_symlink).with(install_path, link_path)
        subject.send(:fetch_bits_and_symlink)
      end
    end

    context 'when unpacked blob does not exist' do
      before { Dir.stub(:exist?).with(install_path).and_return(false) }

      it 'downloads and unpacks blob into install path' do
        Bosh::Agent::Util.should_receive(:unpack_blob).with('baz', 'quux', install_path)
        subject.send(:fetch_bits_and_symlink)
      end

      context 'when download/unpack of blob succeeds' do
        before { Bosh::Agent::Util.stub(:unpack_blob).and_return(nil) }

        it 'relinks unpacked blob to install path' do
          Bosh::Agent::Util.should_receive(:create_symlink).with(install_path, link_path)
          subject.send(:fetch_bits_and_symlink)
        end
      end

      context 'when download/unpack of blob fails' do
        before { Bosh::Agent::Util.stub(:unpack_blob).and_raise(error) }
        let(:error) { Exception.new('error') }

        it 'does not relink unpacked blob' do
          Bosh::Agent::Util.should_not_receive(:create_symlink)
          expect { subject.send(:fetch_bits_and_symlink) }.to raise_error(error)
        end
      end
    end
  end
end
