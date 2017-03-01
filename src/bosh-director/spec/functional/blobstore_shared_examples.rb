require 'tempfile'

module Bosh::Blobstore
  shared_examples_for 'any blobstore client' do
    after(:each) do
      blobstore.delete(@oid) if @oid
      blobstore.delete(@oid2) if @oid2
    end

    describe '#create' do
      it 'should upload a file' do
        Tempfile.open('foo') do |file|
          @oid = blobstore.create(file)
          expect(@oid).to_not be_nil
        end
      end

      it 'should upload a string' do
        @oid = blobstore.create('foobar')
        expect(@oid).to_not be_nil
      end

      it 'should handle uploading the same object twice' do
        @oid = blobstore.create('foobar')
        expect(@oid).to_not be_nil
        @oid2 = blobstore.create('foobar')
        expect(@oid2).to_not be_nil
        expect(@oid).to_not eq @oid2
      end
    end

    describe '#get' do
      it 'should save to a file' do
        @oid = blobstore.create('foobar')
        file = Tempfile.new('contents')
        blobstore.get(@oid, file)
        file.rewind
        expect(file.read).to eq 'foobar'
      end

      it 'should return the contents' do
        @oid = blobstore.create('foobar')

        expect(blobstore.get(@oid)).to eq 'foobar'
      end

      it 'should raise an error when the object is missing' do
        expect { blobstore.get('nonexistent-key') }.to raise_error NotFound, /Blobstore object 'nonexistent-key' not found/
      end
    end

    describe '#delete' do
      context 'when the key exists' do
        it 'should delete an object' do
          @oid = blobstore.create('foobar')

          expect { blobstore.delete(@oid) }.to_not raise_error
          expect(blobstore.exists?(@oid)).to be_falsey

          @oid = nil
        end
      end

      context 'when the key does not exist' do
        it 'should not raise an error' do
          expect { blobstore.delete('nonexistent-key') }.to_not raise_error
        end
      end
    end

    describe '#exists?' do
      it 'should exist after create' do
        @oid = blobstore.create('foobar')
        expect(blobstore.exists?(@oid)).to be true
      end

      it 'should return false if object does not exist' do
        expect(blobstore.exists?('nonexistent-key')).to be false
      end
    end
  end
end
