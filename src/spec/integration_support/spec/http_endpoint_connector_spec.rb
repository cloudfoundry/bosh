require 'spec_helper'
require 'integration_support/http_endpoint_connector'

module IntegrationSupport
  describe HTTPEndpointConnector do
    let(:logger) { double(Logging::Logger).as_null_object }
    let(:http_endpoint_connector) { HTTPEndpointConnector.new('fake-name', '10.10.0.1', '1234', '/fake/path', 'expected-content', 'fake-log-location', logger) }

    describe '#try_to_connect' do
      context 'when connecting fails after some time' do
        before { allow(Timeout).to receive(:timeout).and_raise(error) }
        let(:error) { Timeout::Error.new }

        it 'sleeps after each failed attempt then raises' do
          expect(Timeout).to receive(:timeout).ordered
          expect(http_endpoint_connector).to receive(:sleep).with(0.2).ordered
          expect(Timeout).to receive(:timeout).ordered

          expect {
            http_endpoint_connector.try_to_connect(2)
          }.to raise_error(error)
        end

        it 'defaults to 80 attempts before raising' do
          expect(Timeout).to receive(:timeout).exactly(80).times
          expect(http_endpoint_connector).to receive(:sleep).exactly(79).times

          expect {
            http_endpoint_connector.try_to_connect
          }.to raise_error(error)
        end

        it 'logs name, error and other misc information if error raised' do
          allow(http_endpoint_connector).to receive(:sleep)

          expect(logger).to receive(:error).at_least(1).with(
            /Failed to connect to fake-name: .*Timeout::Error.*10.10.0.1.*1234/)

          expect {
            http_endpoint_connector.try_to_connect
          }.to raise_error(error)
        end
      end

      context 'when connecting fails due to content mismatch' do
        before do
          allow(Net::HTTP).to receive(:get).and_return('non-matching-content')
        end

        it 'logs name, error and other misc information and raises error' do
          allow(http_endpoint_connector).to receive(:sleep)

          expect(logger).to receive(:error).at_least(1).with(
            /Failed to connect to fake-name:.*Expected to find 'expected-content' in 'non-matching-content'/)

          expect {
            http_endpoint_connector.try_to_connect
          }.to raise_error(StandardError, /Expected to find 'expected-content' in 'non-matching-content'/)
        end
      end

      context 'when connecting succeeds' do
        before do
          allow(logger).to receive(:info)
          allow(Net::HTTP).to receive(:get).and_return('expected-content')
        end

        it 'logs successful connection' do
          expect(logger).to receive(:info).with(
            "Connected to fake-name at http://10.10.0.1:1234/fake/path (logs at fake-log-location*)"
          )
          http_endpoint_connector.try_to_connect(2)
        end
      end
    end
  end
end
