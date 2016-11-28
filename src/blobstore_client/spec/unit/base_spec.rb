require 'spec_helper'

describe Bosh::Blobstore::BaseClient do
  subject { described_class.new({}) }

  it_implements_base_client_interface

  describe '#create' do
    it 'should raise a NotImplemented exception' do
      expect { subject.create('contents') }.to raise_error(
        Bosh::Blobstore::NotImplemented, 'not supported by this blobstore')
    end

    it 'should raise BlobstoreError exceptions' do
      expect(subject).to receive(:create_file).and_raise(
        Bosh::Blobstore::BlobstoreError, 'Could not create object')

      expect { subject.create('contents') }.to raise_error(
        Bosh::Blobstore::BlobstoreError, 'Could not create object')
    end

    it 'should trap generic exceptions and raise a BlobstoreError exception' do
      expect(subject).to receive(:create_file).and_raise(
        Errno::ECONNRESET, 'Could not create object')

      expect { subject.create('contents') }.to raise_error(
        Bosh::Blobstore::BlobstoreError,
        /Errno::ECONNRESET: Connection reset by peer - Could not create object/,
      )
    end
  end

  describe '#get' do
    it 'allows to pass options optionally' do
      expect { subject.get('id', 'file')     }.to raise_error(Bosh::Blobstore::NotImplemented)
      expect { subject.get('id', 'file', {}) }.to raise_error(Bosh::Blobstore::NotImplemented)
    end

    it 'should raise a NotImplemented exception' do
      expect { subject.get('id', 'file') }.to raise_error(
        Bosh::Blobstore::NotImplemented, 'not supported by this blobstore')
    end

    it 'should raise BlobstoreError exceptions' do
      expect(subject).to receive(:get_file).and_raise(
        Bosh::Blobstore::BlobstoreError, 'Could not fetch object')

      expect { subject.get('id', 'file') }.to raise_error(
        Bosh::Blobstore::BlobstoreError, 'Could not fetch object')
    end

    it 'should trap generic exceptions and raise a BlobstoreError exception' do
      expect(subject).to receive(:get_file).and_raise(
        Errno::ECONNRESET, 'Could not fetch object')

      expect { subject.get('id', 'file') }.to raise_error(
        Bosh::Blobstore::BlobstoreError,
        /Errno::ECONNRESET: Connection reset by peer - Could not fetch object/,
      )
    end
  end

  describe '#delete' do
    it 'should raise a NotImplemented exception' do
      expect { subject.delete('id') }.to raise_error(
        Bosh::Blobstore::NotImplemented, 'not supported by this blobstore')
    end
  end

  describe '#exists?' do
    it 'should raise a NotImplemented exception' do
      expect { subject.exists?('id') }.to raise_error(
        Bosh::Blobstore::NotImplemented, 'not supported by this blobstore')
    end
  end
end
