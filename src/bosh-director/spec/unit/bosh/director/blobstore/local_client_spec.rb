require 'spec_helper'

module Bosh::Director::Blobstore
  describe LocalClient do
    subject { described_class.new(@options) }

    let(:uuid_a) { 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' }
    let(:uuid_b) { 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12' }

    it_implements_base_client_interface

    before do
      @tmp = Dir.mktmpdir
      @options = { 'blobstore_path' => @tmp }
    end

    after { FileUtils.rm_rf(@tmp) }

    it 'should require blobstore_path option' do
      expect { LocalClient.new({}) }.to raise_error(RuntimeError, /No blobstore path given in options {}/)
    end

    it 'should create blobstore_path directory if it does not exist' do
      dir = File.join(@tmp, 'blobstore')

      LocalClient.new('blobstore_path' => dir)

      expect(File.directory?(dir)).to be(true)
    end

    describe 'operations' do

      describe '#exists?' do
        it 'should return true if the object already exists' do
          File.open(File.join(@tmp, uuid_a), 'w') do |fh|
            fh.puts('bar')
          end

          client = LocalClient.new(@options)
          expect(client.exists?(uuid_a)).to be(true)
        end

        it "should return false if the object doesn't exists" do
          client = LocalClient.new(@options)
          expect(client.exists?(uuid_a)).to be(false)
        end
      end

      describe 'get' do
        it 'should retrieve the correct contents' do
          File.open(File.join(@tmp, uuid_a), 'w') do |fh|
            fh.puts('bar')
          end

          client = LocalClient.new(@options)
          expect(client.get(uuid_a)).to eq("bar\n")
        end

        it 'rejects non-UUID object ids' do
          expect { LocalClient.new(@options).get('foo') }.to raise_error(BlobstoreError, /invalid blobstore object id format/)
        end

        it 'rejects path traversal in object ids' do
          expect do
            LocalClient.new(@options).get('../../etc/passwd')
          end.to raise_error(BlobstoreError, /invalid blobstore object id format/)
        end
      end

      describe 'create' do
        it 'should store a file' do
          test_file = Tempfile.new('file')
          client = LocalClient.new(@options)
          fh = File.open(test_file)
          id = client.create(fh)
          fh.close
          original = File.new(test_file).readlines

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq(original)
          expect(id).to match(UuidValidation::UUID_PATTERN)
        end

        it 'should store a string' do
          client = LocalClient.new(@options)
          string = 'foobar'
          id = client.create(string)

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq([string])
          expect(id).to match(UuidValidation::UUID_PATTERN)
        end

        it 'should accept object id suggestion when it is a UUID' do
          client = LocalClient.new(@options)
          string = 'foobar'

          id = client.create(string, uuid_b)
          expect(id).to eq(uuid_b)

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq([string])
        end

        it 'should raise an error when the suggested UUID is already used' do
          client = LocalClient.new(@options)
          string = 'foobar'
          expect(client.create(string, uuid_b)).to eq(uuid_b)

          expect { client.create(string, uuid_b) }.to raise_error BlobstoreError
        end
      end

      describe 'delete' do
        it 'should delete an id' do
          client = LocalClient.new(@options)
          string = 'foobar'
          id = client.create(string)
          client.delete(id)
          expect(File.exist?(File.join(@tmp, id))).to be(false)
        end

        it 'should not raise NotFound error when trying to delete a missing id' do
          missing_uuid = '00000000-0000-4000-8000-000000000001'
          expect { LocalClient.new(@options).delete(missing_uuid) }.to_not raise_error
        end
      end

      describe 'validation' do
        it 'has no required credential properties' do
          agent_env = {}
          stemcell_api_version = 3
          subject.validate!(agent_env, stemcell_api_version)
        end
      end
    end
  end
end
