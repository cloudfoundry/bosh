require 'spec_helper'

module Bosh::Blobstore
  describe LocalClient do
    subject { described_class.new(@options) }

    it_implements_base_client_interface

    before do
      @tmp = Dir.mktmpdir
      @options = { 'blobstore_path' => @tmp }
    end

    after { FileUtils.rm_rf(@tmp) }

    it 'should require blobstore_path option' do
      expect { LocalClient.new({}) }.to raise_error
    end

    it "should create blobstore_path direcory if it doesn't exist'" do
      dir = File.join(@tmp, 'blobstore')

      LocalClient.new('blobstore_path' => dir)

      expect(File.directory?(dir)).to be(true)
    end

    describe 'operations' do

      describe '#exists?' do
        it 'should return true if the object already exists' do
          File.open(File.join(@tmp, 'foo'), 'w') do |fh|
            fh.puts('bar')
          end

          client = LocalClient.new(@options)
          expect(client.exists?('foo')).to be(true)
        end

        it "should return false if the object doesn't exists" do
          client = LocalClient.new(@options)
          expect(client.exists?('foo')).to be(false)
        end
      end

      describe 'get' do
        it 'should retrive the correct contents' do
          File.open(File.join(@tmp, 'foo'), 'w') do |fh|
            fh.puts('bar')
          end

          client = LocalClient.new(@options)
          expect(client.get('foo')).to eq("bar\n")
        end
      end

      describe 'create' do
        it 'should store a file' do
          test_file = asset('file')
          client = LocalClient.new(@options)
          fh = File.open(test_file)
          id = client.create(fh)
          fh.close
          original = File.new(test_file).readlines

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq(original)
        end

        it 'should store a string' do
          client = LocalClient.new(@options)
          string = 'foobar'
          id = client.create(string)

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq([string])
        end

        it 'should accept object id suggestion' do
          client = LocalClient.new(@options)
          string = 'foobar'

          id = client.create(string, 'foobar')
          expect(id).to eq('foobar')

          stored = File.new(File.join(@tmp, id)).readlines
          expect(stored).to eq([string])
        end

        it 'should raise an error' do
          client = LocalClient.new(@options)
          string = 'foobar'
          expect(client.create(string, 'foobar')).to eq('foobar')

          expect { client.create(string, 'foobar') }.to raise_error BlobstoreError
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

        it 'should raise NotFound error when trying to delete a missing id' do
          expect { LocalClient.new(@options).delete('missing') }.to raise_error NotFound
        end
      end

    end
  end
end

