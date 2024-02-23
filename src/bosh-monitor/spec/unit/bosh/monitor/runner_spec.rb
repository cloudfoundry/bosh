require 'spec_helper'

describe Bosh::Monitor::Runner do
  include_context Async::RSpec::Reactor

  let(:runner) { Bosh::Monitor::Runner.new(sample_config) }
  let(:logger) { instance_double(Logger, info: nil, error: nil, fatal: nil) }

  let(:nats) { instance_double('NATS::IO::Client') }

  let(:rsa_key) { instance_double(OpenSSL::PKey::RSA) }
  let(:x509_cert) { instance_double(OpenSSL::X509::Certificate) }

  let(:rsa_key_content) { 'client_key' }
  let(:x509_cert_content) { 'client_cert' }

  before do
    allow(Bhm).to receive(:logger).and_return(logger)

    runner

    allow(NATS::IO::Client).to receive(:new).and_return(nats)
    allow(nats).to receive(:on_error)
    allow(nats).to receive(:connect)
    allow(nats).to receive(:connected?).and_return(false)
    allow(OpenSSL::PKey::RSA).to receive(:new)
    allow(OpenSSL::X509::Certificate).to receive(:new)
    allow(File).to receive(:open).with(Bhm.mbus.client_private_key_path).and_return(rsa_key_content)
    allow(File).to receive(:open).with(Bhm.mbus.client_certificate_path).and_return(x509_cert_content)
  end

  describe '#handle_fatal_error' do
    context 'when an unhandled event loop error occurs' do
      let(:http_server) { instance_double(Thin::Server) }

      before do
        allow(Thin::Server).to receive(:new).and_return(http_server)
        allow(http_server).to receive(:start!)

        runner.start_http_server
      end

      it 'stops the HM server, stops the event loop and logs the error' do
        allow(Fiber.scheduler).to receive(:close)
        allow(http_server).to receive(:stop!)
        error = StandardError.new('uncaught event loop exception')
        error.set_backtrace(['backtrace'])

        runner.handle_fatal_error(error)

        expect(Fiber.scheduler).to have_received(:close)
        expect(http_server).to have_received(:stop!)
        expect(logger).to have_received(:fatal).with('uncaught event loop exception')
        expect(logger).to have_received(:fatal).with('backtrace')
      end
    end
  end

  describe '#connect_to_mbus' do
    it 'should connect using SSL' do
      expect(OpenSSL::PKey::RSA).to receive(:new).with(rsa_key_content).and_return(rsa_key)
      expect(OpenSSL::X509::Certificate).to receive(:new).with(x509_cert_content).and_return(x509_cert)

      expect(nats).to receive(:connect)

      runner.connect_to_mbus
    end

    context 'when NATS errors' do
      let(:custom_error) { 'Some error for nats://127.0.0.1:4222. Another error for nats://127.0.0.1:4222.' }

      before do
        allow(nats).to receive(:on_error) do |&clbk|
          clbk.call(custom_error)
        end
      end

      context 'when NATS calls error handler with a ConnectError' do
        let(:custom_error) { NATS::IO::ConnectError.new('connection error') }

        it 'shuts down the server' do
          expect(runner).to receive(:stop)

          runner.connect_to_mbus
        end
      end

      context 'when an error occurs while connecting' do
        before do
          allow(nats).to receive(:connect).and_raise('a NATS error has occurred')
        end

        it 'throws the error' do
          expect do
            runner.connect_to_mbus
          end.to raise_error('a NATS error has occurred')
        end
      end
    end
  end
end
