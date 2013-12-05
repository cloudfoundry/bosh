require 'spec_helper'

module Bosh::Blobstore
  describe DavBlobstoreClient do
    subject { described_class.new({}) }
    let(:response) { double(HTTP::Message) }
    let(:httpclient) { double(HTTPClient) }

    before { HTTPClient.stub(new: httpclient) }

    it_implements_base_client_interface

    describe 'options' do
      it 'should set up authentication when present' do
        response.stub(status: 200, content: 'content_id')

        httpclient.should_receive(:get).
          with('http://localhost/88/foobar', {}, { 'Authorization' => 'Basic am9objpzbWl0aA==' }).and_return(response)

        DavBlobstoreClient.new('endpoint' => 'http://localhost', 'user' => 'john', 'password' => 'smith').get('foobar')
      end
    end

    describe 'operations' do
      let(:client) { DavBlobstoreClient.new('endpoint' => 'http://localhost') }

      it 'should create an object' do
        client.stub(generate_object_id: 'foobar')
        response.stub(status: 201, content: '')

        httpclient.should_receive(:put) do |*args|
          uri, body, _ = args
          # sha1 of foobar is 8843d7f92416211de9ebb963ff4ce28125932878
          uri.should eql('http://localhost/88/foobar')
          body.should be_kind_of(File)
          body.read.should eql('some object')
          response
        end

        client.create('some object').should eql('foobar')
      end

      it 'should accept object id suggestion' do
        response.stub(status: 201, content: '')

        httpclient.should_receive(:put) do |uri, body, _|
          uri.should eql('http://localhost/88/foobar')
          body.should be_kind_of(File)
          body.read.should eql('some object')
          response
        end

        client.create('some object', 'foobar').should eql('foobar')
      end

      it 'should raise an exception when there is an error creating an object' do
        response.stub(status: 500, content: nil)

        httpclient.stub(put: response)

        expect { client.create('some object') }.to raise_error BlobstoreError, /Could not create object/
      end

      it 'should fetch an object' do
        response.stub(status: 200)
        httpclient.should_receive(:get).with('http://localhost/88/foobar', {}, {}).and_yield('content').and_return(response)

        client.get('foobar').should eql('content')
      end

      it 'should raise an exception when there is an error fetching an object' do
        response.stub(status: 500, content: 'error message')
        httpclient.should_receive(:get).with('http://localhost/88/foobar', {}, {}).and_return(response)

        expect { client.get('foobar') }.to raise_error BlobstoreError, /Could not fetch object/
      end

      it 'should delete an object' do
        response.stub(status: 204, content: '')
        httpclient.should_receive(:delete).with('http://localhost/88/foobar', {}).and_return(response)

        client.delete('foobar')
      end

      it 'should raise an exception when there is an error deleting an object' do
        response.stub(status: 404, content: '')
        httpclient.should_receive(:delete).with('http://localhost/88/foobar', {}).and_return(response)

        expect { client.delete('foobar') }.to raise_error BlobstoreError, /Could not delete object/
      end

      describe '#exists?' do
        it 'should return true for an object that already exists' do
          response.stub(status: 200)

          httpclient.should_receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          client.exists?('foobar').should be(true)
        end

        it 'should return false for an object that does not exist' do
          response.stub(status: 404)

          httpclient.should_receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          client.exists?('foobar').should be(false)
        end

        it 'should raise a BlobstoreError if response status is neither 200 nor 404' do
          response.stub(status: 500, content: '')

          httpclient.should_receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
        end
      end
    end
  end
end
