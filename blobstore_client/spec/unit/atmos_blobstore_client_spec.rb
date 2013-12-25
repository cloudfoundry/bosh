require 'spec_helper'

module Bosh::Blobstore
  describe AtmosBlobstoreClient do
    subject(:client) { AtmosBlobstoreClient.new(options) }
    let(:options) do
      { url: 'http://localhost',
        uid: 'uid',
        secret: 'secret' }
    end

    before { allow(Atmos::Store).to receive(:new).and_return(atmos) }
    let(:atmos) { double('atmos') }

    before { allow(HTTPClient).to receive(:new).and_return(http_client) }
    let(:http_client) { double('http-client', ssl_config: http_client_ssl_opt) }
    let(:http_client_ssl_opt) { double('http-client-ssl-opts', :verify_mode= => nil) }

    it_implements_base_client_interface

    describe '#initialize' do
      it 'initializes with http_proxy when using http endpoint' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = 'https://proxy.example.com:8080'
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = 'http://proxy.example.com:8080'
        options[:url] = 'http://localhost'
        expect(HTTPClient).to receive(:new).with(proxy: 'http://proxy.example.com:8080')
        client
      end

      it 'initializes with https_proxy when using https endpoint' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = 'https://proxy.example.com:8080'
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = 'http://proxy.example.com:8080'
        options[:url] = 'https://localhost'
        expect(HTTPClient).to receive(:new).with(proxy: 'https://proxy.example.com:8080')
        client
      end

      it 'initializes without proxy settings when env is not set' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = nil
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = nil
        options[:url] = 'https://localhost'
        expect(HTTPClient).to receive(:new)
        client
      end
    end

    describe '#exists?' do
      it 'should return true if the object already exists' do
        object = double(Atmos::Object)
        allow(atmos).to receive(:get).with(id: 'id').and_return(object)

        expect(object).to receive(:exists?).and_return(true)

        expect(client.exists?('id')).to be(true)
      end

      it 'should return false if the object does not exist' do
        object = double(Atmos::Object)
        allow(atmos).to receive(:get).with(id: 'id').and_return(object)

        expect(object).to receive(:exists?).and_return(false)

        expect(client.exists?('id')).to be(false)
      end
    end

    it 'should create an object' do
      data = 'some content'
      object = double('object')

      expect(atmos).to receive(:create) do |opt|
        expect(opt[:data].read).to eq(data)
        expect(opt[:length]).to eq(data.length)
      end.and_return(object)

      expect(object).to receive(:aoid).and_return('test-key')

      object_id = client.create(data)
      object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
      expect(object_info['oid']).to eq('test-key')
      expect(object_info['sig']).to_not be(nil)
    end

    it 'should raise an error if a object id is suggested' do
      expect { client.create('data', 'foobar') }.to raise_error BlobstoreError
    end

    it 'should delete an object' do
      object = double('object')
      expect(atmos).to receive(:get).with(id: 'test-key').and_return(object)
      expect(object).to receive(:delete)

      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))
      client.delete(id)
    end

    it 'should fetch an object' do
      url = 'http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig'
      response = double('response')
      allow(response).to receive(:status).and_return(200)
      expect(http_client).to receive(:get).with(url).and_yield('some-content').and_return(response)
      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))
      expect(client.get(id)).to eq('some-content')
    end

    it 'should refuse to create object without the password' do
      expect { AtmosBlobstoreClient.new({ url: 'http://localhost', uid: 'uid' }).create('foo') }.to raise_error(BlobstoreError)
    end

    it 'should be able to read without password' do
      no_pass_client = AtmosBlobstoreClient.new({ url: 'http://localhost', uid: 'uid' })

      url = 'http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig'
      response = double('response')
      allow(response).to receive(:status).and_return(200)
      expect(http_client).to receive(:get).with(url).and_yield('some-content').and_return(response)
      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))

      expect(no_pass_client.get(id)).to eq('some-content')
    end
  end
end
