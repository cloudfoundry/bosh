require 'spec_helper'

describe Bosh::Director::ConfigServer::RetryableHTTPClient do
  subject { Bosh::Director::ConfigServer::RetryableHTTPClient.new(http_client) }
  let(:http_client) { instance_double('Net::HTTP') }
  let(:connection_error) { Errno::ECONNREFUSED.new('') }
  let(:successful_response) { Net::HTTPSuccess.new(nil, "200", nil) }

  let(:handled_connection_exceptions) do
    [
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::ECONNRESET,
      Timeout::Error,
      Net::HTTPRetriableError,
      OpenSSL::SSL::SSLError,
    ]
  end

  describe '#get' do
    it 'should call `get` on the passed in http_client with same arguments' do
      header = {'key' => 'value'}
      expect(http_client).to receive(:get).with('uri-path', header, nil).and_return(successful_response)
      subject.get('uri-path', header, nil)
    end

    context 'when `get` call fails due to a connection error' do
      it 'throws a connection error after trying 3 times' do
        allow(http_client).to receive(:get).and_raise(connection_error).exactly(3).times
        expect { subject.get('uri-path') }.to raise_error(connection_error)
      end
    end

    context 'when `get` call fails due to a connection error and then recovers on a subsequent retry' do
      before do
        count = 0
        allow(http_client).to receive(:get) do
          count += 1
          if count < 3
            raise connection_error
          end
          successful_response
        end
      end

      it 'does NOT raise an exception' do
        expect(http_client).to receive(:get).exactly(3).times
        expect { subject.get('/hi/ya') }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(successful_response)

      allow(Bosh::Retryable).to receive(:new).with({sleep: 0, tries: 3, on: handled_connection_exceptions}).and_return(retryable)

      subject.get('uri-path')
    end
  end

  describe '#post' do
    it 'should call `post` on the passed in http_client with same arguments' do
      header = {'key' => 'value'}
      expect(http_client).to receive(:post).with('uri-path', '{body}', header, nil).and_return(successful_response)
      subject.post('uri-path', '{body}', header)
    end

    context 'when `post` call fails due to a connection error' do
      it 'throws a connection error after trying 3 times' do
        expect(http_client).to receive(:post).and_raise(connection_error).exactly(3).times
        expect { subject.post('uri-path', '{body}') }.to raise_error(connection_error)
      end
    end

    context 'when `post` call fails due to a connection error and then recovers on a subsequent retry' do
      before do
        count = 0
        allow(http_client).to receive(:post) do
          count += 1
          if count < 3
            raise connection_error
          end
          successful_response
        end
      end

      it 'does NOT raise an exception' do
        expect(http_client).to receive(:post).exactly(3).times
        expect { subject.post('uri-path', '{body}') }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(successful_response)

      allow(Bosh::Retryable).to receive(:new).with({sleep: 0, tries: 3, on: handled_connection_exceptions}).and_return(retryable)

      subject.post('uri-path', '{body}')
    end
  end
end
