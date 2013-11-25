require 'spec_helper'

module Bosh::Blobstore
  describe AtmosBlobstoreClient do
    subject(:client) { AtmosBlobstoreClient.new(options) }
    let(:options) do
      { url: 'http://localhost',
        uid: 'uid',
        secret: 'secret' }
    end

    before { Atmos::Store.stub(new: atmos) }
    let(:atmos) { double('atmos') }

    before { HTTPClient.stub(new: http_client) }
    let(:http_client) { double('http-client', ssl_config: http_client_ssl_opt) }
    let(:http_client_ssl_opt) { double('http-client-ssl-opts', 'verify_mode=' => nil) }

    it_implements_base_client_interface

    describe '#initialize' do
      it 'initializes with http_proxy when using http endpoint' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = 'https://proxy.example.com:8080'
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = 'http://proxy.example.com:8080'
        options[:url] = 'http://localhost'
        HTTPClient.should_receive(:new).with(proxy: 'http://proxy.example.com:8080')
        client
      end

      it 'initializes with https_proxy when using https endpoint' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = 'https://proxy.example.com:8080'
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = 'http://proxy.example.com:8080'
        options[:url] = 'https://localhost'
        HTTPClient.should_receive(:new).with(proxy: 'https://proxy.example.com:8080')
        client
      end

      it 'initializes without proxy settings when env is not set' do
        ENV['HTTPS_PROXY'] = ENV['https_proxy'] = nil
        ENV['HTTP_PROXY']  = ENV['http_proxy']  = nil
        options[:url] = 'https://localhost'
        HTTPClient.should_receive(:new)
        client
      end
    end

    describe '#exists?' do
      it 'should return true if the object already exists' do
        object = double(Atmos::Object)
        atmos.stub(:get).with(id: 'id').and_return(object)

        object.should_receive(:exists?).and_return(true)

        client.exists?('id').should be(true)
      end

      it 'should return false if the object does not exist' do
        object = double(Atmos::Object)
        atmos.stub(:get).with(id: 'id').and_return(object)

        object.should_receive(:exists?).and_return(false)

        client.exists?('id').should be(false)
      end
    end

    it 'should create an object' do
      data = 'some content'
      object = double('object')

      atmos.should_receive(:create).with do |opt|
        opt[:data].read.should eql data
        opt[:length].should eql data.length
      end.and_return(object)

      object.should_receive(:aoid).and_return('test-key')

      object_id = client.create(data)
      object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
      object_info['oid'].should eql('test-key')
      object_info['sig'].should_not be_nil
    end

    it 'should raise an error if a object id is suggested' do
      expect { client.create('data', 'foobar') }.to raise_error BlobstoreError
    end

    it 'should delete an object' do
      object = double('object')
      atmos.should_receive(:get).with(id: 'test-key').and_return(object)
      object.should_receive(:delete)

      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))
      client.delete(id)
    end

    it 'should fetch an object' do
      url = 'http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig'
      response = double('response')
      response.stub(:status).and_return(200)
      http_client.should_receive(:get).with(url).and_yield('some-content').and_return(response)
      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))
      client.get(id).should eql('some-content')
    end

    it 'should refuse to create object without the password' do
      expect { AtmosBlobstoreClient.new({ url: 'http://localhost', uid: 'uid' }).create('foo') }.to raise_error(BlobstoreError)
    end

    it 'should be able to read without password' do
      no_pass_client = AtmosBlobstoreClient.new({ url: 'http://localhost', uid: 'uid' })

      url = 'http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig'
      response = double('response')
      response.stub(:status).and_return(200)
      http_client.should_receive(:get).with(url).and_yield('some-content').and_return(response)
      id = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'test-key', sig: 'sig' })))

      no_pass_client.get(id).should eql('some-content')
    end
  end
end
