require 'spec_helper'

describe Bosh::Deployer::InstanceManager do
  describe '#create' do
    let(:config) { { 'cloud' => { 'plugin' => 'fake-plugin' } } }

    it 'tries to require instance manager specific class' +
       '(this allows custom gems to specify instance manager plugin)' do
      described_class.should_receive(:require).with(
        'bosh/deployer/instance_manager/fake-plugin')
      allow(described_class).to receive(:new)
      described_class.create(config)
    end

    it 'raises an error when requiring non-existent plugin' do
      expect {
        described_class.create(config)
      }.to raise_error(
        Bosh::Cli::CliError,
        /Could not find Provider Plugin: fake-plugin/,
      )
    end

    it 'returns the plugin specific instance manager' do
      described_class.stub(:require)

      fingerprinter = instance_double('Bosh::Deployer::HashFingerprinter')
      Bosh::Deployer::HashFingerprinter
        .should_receive(:new)
        .and_return(fingerprinter)

      fingerprinter
        .should_receive(:sha1)
        .with(config)
        .and_return('fake-config-sha1')

      ui_messager = instance_double('Bosh::Deployer::UiMessager')
      Bosh::Deployer::UiMessager
        .should_receive(:for_deployer)
        .and_return(ui_messager)

      allow(described_class).to receive(:new)

      described_class.create(config)

      expect(described_class).to have_received(:new).
                                   with(config, 'fake-config-sha1', ui_messager, 'fake-plugin')
    end

    it 'retries on ConnectTimeoutError, BadResponseError when waiting for agent and director through a proxy' do
      s = :CONNECTION_EXCEPTIONS  # rubocop:disable SymbolName
      connect_exceptions = Bosh::Deployer::InstanceManager.const_get(s)
      connect_exceptions.should include HTTPClient::ConnectTimeoutError
      connect_exceptions.should include HTTPClient::BadResponseError
    end
  end
end
