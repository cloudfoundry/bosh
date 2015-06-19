require 'spec_helper'
require 'tempfile'

describe VSphereCloud::SoapStub do
  let(:soap_stub) { described_class.new('https://some-host/sdk/vimService', soap_log) }
  let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }
  let(:http_client) do
    instance_double('HTTPClient',
      :debug_dev= => nil,
      :send_timeout= => nil,
      :receive_timeout= => nil,
      :connect_timeout= => nil,
      :ssl_config => ssl_config,
    )
  end
  before { allow(HTTPClient).to receive(:new).and_return(http_client) }

  describe '#create' do
    def self.it_configures_http_client
      it 'configures http client ' do
        expect(http_client).to receive(:send_timeout=).with(14400)
        expect(http_client).to receive(:receive_timeout=).with(14400)
        expect(http_client).to receive(:connect_timeout=).with(30)
        expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

        soap_stub.create
      end
    end

    context 'when soap log is an IO' do
      let(:soap_log) { IO.new(0) }

      it 'uses given IO for http_client logging' do
        expect(http_client).to receive(:debug_dev=).with(soap_log)
        expect(VimSdk::Soap::StubAdapter).to receive(:new).with('https://some-host/sdk/vimService', 'vim.version.version8', http_client)

        soap_stub.create
      end

      it_configures_http_client
    end

    context 'when soap log is a StringIO' do
      let(:soap_log) { StringIO.new }

      it 'uses given IO for http_client logging' do
        expect(http_client).to receive(:debug_dev=).with(soap_log)
        expect(VimSdk::Soap::StubAdapter).to receive(:new).with('https://some-host/sdk/vimService', 'vim.version.version8', http_client)

        soap_stub.create
      end

      it_configures_http_client
    end

    context 'when soap log is a file path' do
      let(:soap_log) { Tempfile.new('fake-log-file').path }
      after { FileUtils.rm_rf(soap_log) }

      it 'creates a file IO for http_client logging' do
        expect(http_client).to receive(:debug_dev=) do |log_file|
          expect(log_file).to be_instance_of(File)
          expect(log_file.path).to eq(soap_log)
        end

        expect(VimSdk::Soap::StubAdapter).to receive(:new).with('https://some-host/sdk/vimService', 'vim.version.version8', http_client)

        soap_stub.create
      end

      it_configures_http_client
    end
  end
end
