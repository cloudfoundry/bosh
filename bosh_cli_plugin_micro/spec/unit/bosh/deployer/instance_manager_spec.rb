require 'spec_helper'
require 'bosh/deployer/microbosh_job_instance'
require 'bosh/deployer/deployments_state'

module Bosh::Deployer
  describe InstanceManager do
    let(:config) { instance_double('Bosh::Deployer::Configuration') }
    let(:config_hash) { { 'cloud' => { 'plugin' => 'fake' } } }
    let(:infrastructure) { double(:infrastructure) }
    let(:state) { double(:state, uuid: nil) }
    let(:deployments_state) { instance_double('Bosh::Deployer::DeploymentsState') }
    let(:microbosh_job_instance) { instance_double('Bosh::Deployer::MicroboshJobInstance') }
    let(:spec) { instance_double('Bosh::Deployer::Specification') }
    let(:logger) { instance_double('Logger', info: nil, error: nil) }

    subject(:instance_manager) { described_class.create(config_hash) }

    before do
      allow(Config).to receive(:configure).and_return(config)
      allow(config).to receive(:logger).and_return(logger)
      allow(config).to receive(:base_dir)
      allow(config).to receive(:name)
      allow(config).to receive(:uuid=)
      allow(config).to receive(:agent_services_ip)
      allow(config).to receive(:internal_services_ip)
      allow(config).to receive(:agent_url).and_return('http://user:password@agent-url.com')
      allow(config).to receive(:uuid)

      class_double('Bosh::Deployer::MicroboshJobInstance').as_stubbed_const
      allow(MicroboshJobInstance).to receive(:new).and_return(microbosh_job_instance)
      allow(microbosh_job_instance).to receive(:render_templates).and_return(spec)
      allow(spec).to receive(:update).and_return(spec)

      allow(described_class).to receive(:require).with('bosh/deployer/instance_manager/fake')
      fake_plugin_class = double(:fake_plugin_class, new: infrastructure)
      allow(described_class).to receive(:const_get).with('Fake').and_return(fake_plugin_class)
      allow(infrastructure).to receive(:update_spec)
      allow(infrastructure).to receive(:client_services_ip).and_return('client-ip')

      allow(Bosh::Agent::HTTPClient).to receive(:new).and_return(double('agent', run_task: nil))

      class_double('Bosh::Deployer::DeploymentsState').as_stubbed_const
      allow(DeploymentsState).to receive(:load_from_dir).and_return(deployments_state)
      allow(deployments_state).to receive(:load_deployment)
      allow(deployments_state).to receive(:state).and_return(state)

      allow(instance_manager).to receive(:step).and_yield
    end

    describe '.create' do
      let(:config_hash) { { 'cloud' => { 'plugin' => 'fake' } } }

      it 'tries to require instance manager specific class' +
           '(this allows custom gems to specify instance manager plugin)' do
        expect(described_class).to receive(:require).with(
          'bosh/deployer/instance_manager/fake')
        allow(described_class).to receive(:new)
        described_class.create(config_hash)
      end

      it 'raises an error when requiring non-existent plugin' do
        config_hash_with_non_existent_plugin = config_hash.dup
        config_hash_with_non_existent_plugin['cloud']['plugin'] = 'does not exist'

        endpoint = 'bosh/deployer/instance_manager/does not exist'
        allow(described_class).to receive(:require).with(endpoint).and_raise(LoadError)

        expect {
          described_class.create(config_hash_with_non_existent_plugin)
        }.to raise_error(
               Bosh::Cli::CliError,
               /Could not find Provider Plugin: does not exist/,
             )
      end

      it 'returns the plugin specific instance manager' do
        allow(described_class).to receive(:require)

        fingerprinter = instance_double('Bosh::Deployer::HashFingerprinter')
        expect(HashFingerprinter)
        .to receive(:new)
        .and_return(fingerprinter)

        expect(fingerprinter)
        .to receive(:sha1)
        .with(config_hash)
        .and_return('fake-config-hash-sha1')

        ui_messager = instance_double('Bosh::Deployer::UiMessager')
        expect(UiMessager)
        .to receive(:for_deployer)
        .and_return(ui_messager)

        expect(Config).to receive(:configure).with(config_hash)

        allow(described_class).to receive(:new)

        described_class.create(config_hash)

        expect(described_class).to have_received(:new).
                                     with(config, 'fake-config-hash-sha1', ui_messager, 'fake')
      end
    end

    describe '#agent_services_ip' do
      it 'delegates to the configuration' do
        allow(infrastructure).to receive(:agent_services_ip).and_return('agent_ip')

        expect(instance_manager.agent_services_ip).to eq('agent_ip')
      end
    end

    describe '#client_services_ip' do
      it 'delegates to the configuration' do
        allow(infrastructure).to receive(:client_services_ip).and_return('client_ip')

        expect(instance_manager.client_services_ip).to eq('client_ip')
      end
    end

    describe '#internal_services_ip' do
      it 'delegates to the configuration' do
        allow(infrastructure).to receive(:internal_services_ip).and_return('internal_ip')

        expect(instance_manager.internal_services_ip).to eq('internal_ip')
      end
    end

    describe '#agent' do
      it 'should be set with the client ip' do
        expect(Bosh::Agent::HTTPClient).to receive(:new) do |uri, _|
          expect(uri).to include('client-ip')
        end

        subject.agent
      end
    end

    describe '#apply' do
      before do
        allow(Bosh::Agent::HTTPClient).to receive(:new).and_return(double('agent', run_task: nil))
        allow(infrastructure).to receive(:update_spec)
        allow(infrastructure).to receive(:agent_services_ip).and_return('agent_ip')
        allow(infrastructure).to receive(:internal_services_ip).and_return('internal_ip')
        allow(config).to receive(:logger).and_return('logger')
      end

      it 'updates the spec with agent service & internal service IPs' do
        expect(spec).to receive(:update).with('agent_ip', 'internal_ip').and_return(spec)

        instance_manager.apply(spec)
      end

      it 'uses the client service IP to render job templates' do
        expect(MicroboshJobInstance).to receive(:new).
          with('client-ip', 'http://user:password@agent-url.com', 'logger')

        instance_manager.apply(spec)
      end
    end

    # TODO: just test wait_until_directory_ready?
    describe '#create' do
      let(:http_client) { instance_double('HTTPClient') }
      let(:director_response) { double(:response, status: 200, body: '{}') }
      let(:stemcell_archive) { double('stemcell archive', sha1: nil) }
      let(:ssl_config) { double(:http_client_ssl_config).as_null_object }
      let(:state) { double('state').as_null_object }
      let(:infrastructure) { double('infrastructure').as_null_object }
      let(:agent) { double(Bosh::Agent::HTTPClient) }

      before do
        allow(instance_manager).to receive(:err)

        allow(state).to receive(:vm_cid)
        allow(deployments_state).to receive(:save)

        allow(config).to receive(:resources).and_return({})
        allow(config).to receive(:networks)
        allow(config).to receive(:env)
        allow(config).to receive(:cloud).and_return(infrastructure)

        allow(HTTPClient).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:get).and_return(director_response)
        allow(http_client).to receive(:ssl_config).and_return(ssl_config)

        allow(Specification).to receive(:new).and_return(spec)
        allow(spec).to receive(:director_port).and_return(80808)

        class_double('Bosh::Common').as_stubbed_const
        allow(Bosh::Common).to receive(:retryable).and_yield(0, nil)

        allow(Bosh::Agent::HTTPClient).to receive(:new).and_return(agent)
        allow(agent).to receive(:run_task)
        allow(agent).to receive(:ping)
        allow(agent).to receive(:list_disk).and_return([])
        allow(agent).to receive(:release_apply_spec)
      end

      it 'contacts the director on the client_services_ip to see if it is ready' do
        instance_manager.create('stemcell', stemcell_archive)

        expect(http_client).to have_received(:get).with('https://client-ip:80808/info')
      end
    end

    describe '#create_disk' do
      before do
        allow(config).to receive(:cloud).and_return(infrastructure)
        allow(state).to receive(:vm_cid).and_return('fake-vm-cid')
        allow(infrastructure).to receive(:create_disk).and_return('fake-disk-cid')
        allow(state).to receive(:disk_cid=).with('fake-disk-cid')

        allow(config).to receive(:resources).and_return({
          'persistent_disk' => 'fake-disk-size',
          'persistent_disk_cloud_properties' => 'fake-cloud-properties',
        })
        allow(deployments_state).to receive(:save).with(infrastructure)
      end

      it 'passes the persistent_disk_cloud_properties to the cloud' do
        expect(infrastructure).to receive(:create_disk).
          with('fake-disk-size', 'fake-cloud-properties', 'fake-vm-cid')
        instance_manager.create_disk
      end

      it 'falls back if there are no persistent_disk_cloud_properties' do
        allow(config).to receive(:resources).and_return({
          'persistent_disk' => 'fake-disk-size',
        })
        expect(infrastructure).to receive(:create_disk).with('fake-disk-size', {}, 'fake-vm-cid')
        instance_manager.create_disk
      end
    end
  end
end
