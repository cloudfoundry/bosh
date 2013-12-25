require 'spec_helper'

module Bosh::Blobstore
  describe DavBlobstoreClient do
    subject { described_class.new({}) }
    let(:response) { double(HTTP::Message) }
    let(:httpclient) { double(HTTPClient) }

    before { allow(HTTPClient).to receive_messages(new: httpclient) }

    it_implements_base_client_interface

    describe 'options' do
      it 'should set up authentication when present' do
        allow(response).to receive_messages(status: 200, content: 'content_id')

        expect(httpclient).to receive(:get).
          with('http://localhost/88/foobar', {}, { 'Authorization' => 'Basic am9objpzbWl0aA==' }).and_return(response)

        DavBlobstoreClient.new('endpoint' => 'http://localhost', 'user' => 'john', 'password' => 'smith').get('foobar')
      end
    end

    describe 'operations' do
      let(:client) { DavBlobstoreClient.new('endpoint' => 'http://localhost') }

      it 'should create an object' do
        allow(client).to receive_messages(generate_object_id: 'foobar')
        allow(response).to receive_messages(status: 201, content: '')

        expect(httpclient).to receive(:put) do |*args|
          uri, body, _ = args
          # sha1 of foobar is 8843d7f92416211de9ebb963ff4ce28125932878
          expect(uri).to eq('http://localhost/88/foobar')
          expect(body).to be_kind_of(File)
          expect(body.read).to eq('some object')
          response
        end

        expect(client.create('some object')).to eq('foobar')
      end

      it 'should accept object id suggestion' do
        allow(response).to receive_messages(status: 201, content: '')

        expect(httpclient).to receive(:put) do |uri, body, _|
          expect(uri).to eq('http://localhost/88/foobar')
          expect(body).to be_kind_of(File)
          expect(body.read).to eq('some object')
          response
        end

        expect(client.create('some object', 'foobar')).to eq('foobar')
      end

      it 'should raise an exception when there is an error creating an object' do
        allow(response).to receive_messages(status: 500, content: nil)

        allow(httpclient).to receive_messages(put: response)

        expect { client.create('some object') }.to raise_error BlobstoreError, /Could not create object/
      end

      it 'should fetch an object' do
        allow(response).to receive_messages(status: 200)
        expect(httpclient).to receive(:get).with('http://localhost/88/foobar', {}, {}).and_yield('content').and_return(response)

        expect(client.get('foobar')).to eq('content')
      end

      it 'should raise an exception when there is an error fetching an object' do
        allow(response).to receive_messages(status: 500, content: 'error message')
        expect(httpclient).to receive(:get).with('http://localhost/88/foobar', {}, {}).and_return(response)

        expect { client.get('foobar') }.to raise_error BlobstoreError, /Could not fetch object/
      end

      it 'should delete an object' do
        allow(response).to receive_messages(status: 204, content: '')
        expect(httpclient).to receive(:delete).with('http://localhost/88/foobar', {}).and_return(response)

        client.delete('foobar')
      end

      it 'should raise an exception when there is an error deleting an object' do
        allow(response).to receive_messages(status: 404, content: '')
        expect(httpclient).to receive(:delete).with('http://localhost/88/foobar', {}).and_return(response)

        expect { client.delete('foobar') }.to raise_error BlobstoreError, /Could not delete object/
      end

      describe '#exists?' do
        it 'should return true for an object that already exists' do
          allow(response).to receive_messages(status: 200)

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          expect(client.exists?('foobar')).to be(true)
        end

        it 'should return false for an object that does not exist' do
          allow(response).to receive_messages(status: 404)

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          expect(client.exists?('foobar')).to be(false)
        end

        it 'should raise a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
        end
      end
    end
  end
end
