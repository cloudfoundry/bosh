require 'spec_helper'

module Bosh::Blobstore
  describe DavBlobstoreClient do
    subject { described_class.new(options) }
    let(:options) { {} }
    let(:response) { double(HTTP::Message) }
    let(:httpclient) { double(HTTPClient) }
    let(:ssl_config) { instance_double('HTTPClient::SSLConfig') }

    before do
      allow(HTTPClient).to receive_messages(new: httpclient)
      allow(httpclient).to receive_messages(ssl_config: ssl_config)
      allow(ssl_config).to receive(:verify_mode=)
      allow(ssl_config).to receive(:verify_callback=)
    end

    it_implements_base_client_interface

    describe 'options' do
      before do
        allow(response).to receive_messages(status: 200, content: 'content_id')
        allow(httpclient).to receive(:get).and_return(response)

        options.merge!(
          'endpoint' => 'http://localhost',
          'user' => 'john',
          'password' => 'smith',
        )
      end

      context 'ssl_no_verify set to true' do
        it 'should set up authentication when present' do
          options.merge!('ssl_no_verify' => true)

          subject.get('foobar')

          expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
          expect(ssl_config).to have_received(:verify_callback=)
        end
      end

      it 'should set up authentication when present' do
        subject.get('foobar')

        expect(httpclient).to have_received(:get)
                              .with('http://localhost/88/foobar', {}, { 'Authorization' => 'Basic am9objpzbWl0aA==' })
      end
    end

    describe 'operations' do
      before { options.merge!('endpoint' => 'http://localhost') }

      it 'should create an object' do
        allow(subject).to receive_messages(generate_object_id: 'foobar')
        allow(response).to receive_messages(status: 201, content: '')

        expect(httpclient).to receive(:put) do |*args|
          uri, body, _ = args
          # sha1 of foobar is 8843d7f92416211de9ebb963ff4ce28125932878
          expect(uri).to eq('http://localhost/88/foobar')
          expect(body).to be_kind_of(File)
          expect(body.read).to eq('some object')
          response
        end

        expect(subject.create('some object')).to eq('foobar')
      end

      it 'should accept object id suggestion' do
        allow(response).to receive_messages(status: 201, content: '')

        expect(httpclient).to receive(:put) do |uri, body, _|
          expect(uri).to eq('http://localhost/88/foobar')
          expect(body).to be_kind_of(File)
          expect(body.read).to eq('some object')
          response
        end

        expect(subject.create('some object', 'foobar')).to eq('foobar')
      end

      it 'should raise an exception when there is an error creating an object' do
        allow(response).to receive_messages(status: 500, content: nil)

        allow(httpclient).to receive_messages(put: response)

        expect { subject.create('some object') }.to raise_error BlobstoreError, /Could not create object/
      end

      it 'should fetch an object' do
        allow(response).to receive_messages(status: 200)
        expect(httpclient).to receive(:get).with('http://localhost/88/foobar', {}, {}).and_yield('content').and_return(response)

        expect(subject.get('foobar')).to eq('content')
      end

      it 'should raise an exception when there is an error fetching an object' do
        allow(response).to receive_messages(status: 500, content: 'error message')
        expect(httpclient).to receive(:get).with('http://localhost/88/foobar', {}, {}).and_return(response)

        expect { subject.get('foobar') }.to raise_error BlobstoreError, /Could not fetch object/
      end

      it 'should delete an object' do
        allow(response).to receive_messages(status: 204, content: '')
        expect(httpclient).to receive(:delete).with('http://localhost/88/foobar', header: {}).and_return(response)

        subject.delete('foobar')
      end

      it 'should raise Bosh::Blobstore::NotFound error when the file is not found in blobstore during deleting' do
        allow(response).to receive_messages(status: 404, content: 'Not Found')
        expect(httpclient).to receive(:delete).with('http://localhost/88/foobar', header: {}).and_return(response)
        expect {
          subject.delete('foobar')
        }.to raise_error NotFound, /Object 'foobar' is not found/
      end

      it 'should raise an exception when there is an error deleting an object' do
        allow(response).to receive_messages(status: 500, content: '')
        expect(httpclient).to receive(:delete).with('http://localhost/88/foobar', header: {}).and_return(response)

        expect { subject.delete('foobar') }.to raise_error BlobstoreError, /Could not delete object/
      end

      describe '#exists?' do
        it 'should return true for an object that already exists' do
          allow(response).to receive_messages(status: 200)

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          expect(subject.exists?('foobar')).to be(true)
        end

        it 'should return false for an object that does not exist' do
          allow(response).to receive_messages(status: 404)

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)
          expect(subject.exists?('foobar')).to be(false)
        end

        it 'should raise a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')

          expect(httpclient).to receive(:head).with('http://localhost/88/foobar', header: {}).and_return(response)

          expect { subject.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
        end
      end
    end
  end
end
