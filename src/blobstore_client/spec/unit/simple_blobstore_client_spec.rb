require 'spec_helper'

module Bosh::Blobstore
  describe SimpleBlobstoreClient do
    subject(:client) { SimpleBlobstoreClient.new('endpoint' => 'http://localhost') }

    it_implements_base_client_interface

    let(:response) { double(HTTP::Message) }
    let(:httpclient) { double(HTTPClient) }

    before { allow(HTTPClient).to receive_messages(new: httpclient) }

    describe 'options' do
      it 'should set up authentication when present' do
        allow(response).to receive_messages(status: 200, content: 'content_id')

        expect(httpclient).to receive(:get).with(
          'http://localhost/resources/foo',
          :header => { 'Authorization' => 'Basic am9objpzbWl0aA==' },
        ).and_return(response)

        SimpleBlobstoreClient.new(
          'endpoint' => 'http://localhost',
          'user' => 'john',
          'password' => 'smith'
        ).get('foo')
      end
    end

    describe 'operations' do
      it 'should create an object' do
        allow(response). to receive_messages(status: 200, content: 'content_id')
        expect(httpclient).to receive(:post) do |*args|
          uri, body, _ = args
          expect(uri).to eq('http://localhost/resources')
          expect(body).to  be_kind_of(Hash)
          expect(body[:content]).to be_kind_of(File)
          expect(body[:content].read).to eq('some object')
          response
        end

        expect(client.create('some object')).to eq('content_id')
      end

      it 'should accept object id suggestion' do
        allow(response).to receive_messages(status: 200, content: 'foobar')
        expect(httpclient).to receive(:post) do |uri, body, _|
          expect(uri).to eq('http://localhost/resources/foobar')
          expect(body).to be_kind_of(Hash)
          expect(body[:content]).to be_kind_of(File)
          expect(body[:content].read).to eq('some object')
          response
        end

        expect(client.create('some object', 'foobar')).to eq('foobar')
      end

      it 'should raise an exception when there is an error creating an object' do
        allow(response).to receive_messages(status: 500, content: nil)

        allow(httpclient).to receive_messages(post: response)

        expect { client.create('some object') }.to raise_error BlobstoreError, /Could not create object/
      end

      it 'should fetch an object' do
        allow(response).to receive_messages(status: 200)
        expect(httpclient).to receive(:get).
          with('http://localhost/resources/some object', :header => {}).
          and_yield('content_id').
          and_return(response)

        expect(client.get('some object')).to eq('content_id')
      end

      it 'should raise an exception when there is an error fetching an object' do
        allow(response).to receive_messages(status: 500, content: 'error message')
        expect(httpclient).to receive(:get).
          with('http://localhost/resources/some object', :header => {}).
          and_return(response)

        expect { client.get('some object') }.to raise_error BlobstoreError, /Could not fetch object/
      end

      it 'should delete an object' do
        allow(response).to receive_messages(status: 204, content: '')
        expect(httpclient).to receive(:delete).
          with('http://localhost/resources/some object', :header => {}).
          and_return(response)

        client.delete('some object')
      end

      it 'should raise Bosh::Blobstore::NotFound error when the file is not found in blobstore during deleting' do
        allow(response).to receive_messages(status: 404, content: '')
        expect(httpclient).to receive(:delete).
          with('http://localhost/resources/some object', :header => {}).
          and_return(response)

        expect { client.delete('some object') }.to raise_error NotFound, /Object 'some object' is not found/
      end

      it 'should raise an exception when there is an error deleting an object' do
        allow(response).to receive_messages(status: 500, content: '')
        expect(httpclient).to receive(:delete).
          with('http://localhost/resources/some object', :header => {}).
          and_return(response)

        expect { client.delete('some object') }.to raise_error BlobstoreError, /Could not delete object/
      end

      describe '#exists?' do
        it 'should return true for an object that already exists' do
          allow(response).to receive_messages(status: 200)

          expect(httpclient).to receive(:head).with('http://localhost/resources/foobar', header: {}).and_return(response)
          expect(client.exists?('foobar')).to be(true)
        end

        it 'should return false for an object that does not exist' do
          allow(response).to receive_messages(status: 404)

          expect(httpclient).to receive(:head).with('http://localhost/resources/doesntexist', header: {}).and_return(response)
          expect(client.exists?('doesntexist')).to be(false)
        end

        it 'should raise a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')

          expect(httpclient).to receive(:head).with('http://localhost/resources/foobar', header: {}).and_return(response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
        end
      end
    end
  end
end
