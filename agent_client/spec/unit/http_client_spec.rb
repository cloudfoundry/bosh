require 'spec_helper'

describe Bosh::Agent::HTTPClient do
  before(:each) do
    @httpclient = double('httpclient')
    allow(@httpclient).to receive(:ssl_config).and_return(double('sslconfig').as_null_object)
    allow(HTTPClient).to receive(:new).and_return(@httpclient)
  end

  describe 'options' do
    it 'should set up authentication when present' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:body).and_return('{"value": "pong"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      expect(@httpclient).to receive(:set_auth).with('https://localhost', 'john', 'smith')
      expect(@httpclient).to receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new('https://localhost',
                                            'user' => 'john',
                                            'password' => 'smith')
      @client.ping
    end

    it 'should encode arguments' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:body).and_return('{"value": "iam"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      headers = { 'Content-Type' => 'application/json' }
      payload = '{"method":"shh","arguments":["hunting","wabbits"],"reply_to":"elmer"}'

      expect(@httpclient).to receive(:request).with(:post, 'https://localhost/agent',
                                                body: payload, header: headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new('https://localhost', { 'reply_to' => 'elmer' })

      expect(@client.shh('hunting', 'wabbits')).to eq 'iam'
    end

    it 'should receive a message value' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:body).and_return('{"value": "pong"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      headers = { 'Content-Type' => 'application/json' }
      payload = '{"method":"ping","arguments":[],"reply_to":"fudd"}'

      expect(@httpclient).to receive(:request).with(:post, 'https://localhost/agent',
                                                body: payload, header: headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new('https://localhost', { 'reply_to' => 'fudd' })

      expect(@client.ping).to eq 'pong'
    end

    it 'should run_task' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:body).and_return('{"value": {"state": "running", "agent_task_id": "task_id_foo"}}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      headers = { 'Content-Type' => 'application/json' }
      payload = '{"method":"compile_package","arguments":["id","sha1"],"reply_to":"bugs"}'

      expect(@httpclient).to receive(:request).with(:post, 'https://localhost/agent',
                                                body: payload, header: headers).and_return(response)

      response2 = double('response2')
      allow(response2).to receive(:code).and_return(200)
      allow(response2).to receive(:body).and_return('{"value": {"state": "done"}')

      payload = '{"method":"get_task","arguments":["task_id_foo"],"reply_to":"bugs"}'

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      expect(@httpclient).to receive(:request).with(:post, 'https://localhost/agent',
                                                body: payload, header: headers).and_return(response2)

      @client = Bosh::Agent::HTTPClient.new('https://localhost', { 'reply_to' => 'bugs' })

      expect(@client.run_task(:compile_package, 'id', 'sha1')).to eq('state' => 'done')
    end

    it 'should raise handler exception when method is invalid' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:body).and_return('{"exception": "no such method"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
       expect(@httpclient).to receive(method)
      end

      expect(@httpclient).to receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new('https://localhost')

      expect { @client.no_such_method }.to raise_error(Bosh::Agent::HandlerError)

    end

    it 'should raise authentication exception when 401 is returned' do
      response = double('response')
      allow(response).to receive(:code).and_return(401)

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        expect(@httpclient).to receive(method)
      end

      expect(@httpclient).to receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new('https://localhost')

      expect { @client.ping }.to raise_error(Bosh::Agent::AuthError)
    end
  end

  describe 'making a request' do
    describe 'error handling' do
      it 'should raise an error specifying the type of error and details of the failed request' do
        @client = Bosh::Agent::HTTPClient.new(
            'base_uri',
            { 'user' => 'yooser', 'password' => '90553076' }
        )

        [:send_timeout=, :receive_timeout=, :connect_timeout=, :set_auth].each do |method|
          allow(@httpclient).to receive(method)
        end
        allow(@httpclient).to receive(:request).and_raise(ZeroDivisionError, '3.14')

        expect { @client.foo('argz') }.to raise_error(
                                              Bosh::Agent::Error,
                                              /base_uri.+foo.+argz.+yooser.+90553076.+ZeroDivisionError: 3\.14/m
                                          )
      end
    end
  end
end
