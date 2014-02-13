require 'spec_helper'

module VSphereCloud
  describe Config do
    subject(:config) { described_class.new(config_hash) }
    let(:agent_config) { { 'fake-agent' => 'configuration' } }
    let(:user) { 'foo-user' }
    let(:password) { 'bar-password' }
    let(:host) { 'some-host' }
    let(:datacenter_name) { 'fancy-datacenter' }
    let(:vm_folder) { 'vm-folder' }
    let(:template_folder) { 'template-folder' }
    let(:disk_path) { '/a/path/on/disk' }
    let(:datastore_pattern) { 'fancy-datastore*' }
    let(:persistent_datastore_pattern) { 'long-lasting-datastore*' }
    let(:cluster_name) { 'grubby-cluster' }
    let(:resource_pool) { 'wading-pool' }
    let(:datacenters) do
      [{
         'name' => datacenter_name,
         'vm_folder' => vm_folder,
         'template_folder' => template_folder,
         'disk_path' => disk_path,
         'datastore_pattern' => datastore_pattern,
         'persistent_datastore_pattern' => persistent_datastore_pattern,
         'clusters' => [
           cluster_name => {
             'resource_pool' => resource_pool,
           }
         ],
       }]
    end

    let(:config_hash) do
      {
        'agent' => agent_config,
        'vcenters' => [
          'host' => host,
          'user' => user,
          'password' => password,
          'datacenters' => datacenters,
        ],
      }
    end

    let(:logger) { instance_double('Logger') }
    before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger) }

    describe '.build' do
      context 'when the config is valid' do
        it 'returns a Config' do
          config = described_class.build(config_hash)
          expect(config).to be_a(VSphereCloud::Config)
          expect(config.agent).to eq(agent_config)
        end
      end

      context 'when the config is invalid' do
        before { config_hash['vcenters'] = [{ 'one' => 'vcenter' }, { 'two' => 'vcenter' }] }
        it 'raises' do
          expect do
            described_class.build(config_hash)
          end.to raise_error(RuntimeError, 'vSphere CPI only supports a single vCenter')
        end
      end
    end

    describe '#validate' do
      context 'when the config is valid' do
        it 'does not raise' do
          expect { config.validate }.to_not raise_exception
        end
      end

      context 'when already validated' do
        before { config.validate }

        it 'does nothing' do
          expect(config).to_not receive(:validate_schema)
        end
      end

      context 'when multiple vcenters are passed in config' do
        before { config_hash['vcenters'] = [{ 'one' => 'vcenter' }, { 'two' => 'vcenter' }] }

        it 'raises' do
          expect do
            config.validate
          end.to raise_error(RuntimeError, 'vSphere CPI only supports a single vCenter')
        end
      end

      context 'when multiple datacenters are passed in config' do
        before { config_hash.merge!({ 'vcenters' => [{ 'datacenters' => [{ 'name' => 'datacenter' }, { 'name' => 'datacenter2' }] }] }) }

        it 'raises' do
          expect do
            config.validate
          end.to raise_error(RuntimeError, 'vSphere CPI only supports a single datacenter')
        end
      end

      context 'when the configuration hash does not match the schema' do
        before { config_hash.delete('agent') }

        it 'raises' do
          expect do
            config.validate
          end.to raise_error(Membrane::SchemaValidationError)
        end
      end
    end

    describe '#logger' do
      it 'delegates to global Config.logger' do
        expect(config.logger).to eq(logger)
      end
    end

    describe '#client' do
      let(:client) { instance_double('VSphereCloud::Client') }

      before do
        config_hash.merge!({ 'cpi_log' => 'batz-log' })
        allow(Client).to receive(:new).with("https://#{host}/sdk/vimService", {
          'soap_log' => config_hash['cpi_log']
        }).and_return(client)
      end

      context 'when the client has not been created yet' do
        it 'returns a new VSphereCloud::Client built from correct params' do
          expect(client).to receive(:login).with(user, password, 'en')

          expect(config.client).to eq(client)
        end
      end

      context 'when the client has already been created' do
        before do
          allow(client).to receive(:login).with(user, password, 'en')
          config.client
        end

        it 'caches client for thread safety' do
          expect(Client).to_not receive(:new)
          config.client
        end
      end
    end

    describe '#rest_client' do
      let(:rest_client) { instance_double('HTTPClient', ssl_config: ssl_config, cookie_manager: cookie_manager) }
      let(:cookie_manager) { instance_double('WebAgent::CookieManager', parse: nil) }
      let(:ssl_config) { instance_double('HTTPClient::SSLConfig') }
      let(:client) { instance_double('VSphereCloud::Client', login: nil, soap_stub: stub_adapter) }
      let(:stub_adapter) { instance_double('VimSdk::Soap::StubAdapter', cookie: nil) }

      before do
        allow(HTTPClient).to receive(:new).exactly(1).times.and_return(rest_client)
        allow(rest_client).to receive(:send_timeout=).with(14400)
        allow(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
        allow(Client).to receive(:new).with("https://#{host}/sdk/vimService", {
          'soap_log' => config_hash['cpi_log']
        }).and_return(client)
      end

      context 'when the rest client has not been created yet' do
        it 'sets send_timeout to 1400' do
          expect(rest_client).to receive(:send_timeout=).with(14400)
          config.rest_client
        end

        it 'sets SSL verify mode to none' do
          expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
          config.rest_client
        end

        it 'copies the cookie from the SOAP client to the rest client' do
          expect(stub_adapter).to receive(:cookie).and_return('fake-cookie')
          expect(cookie_manager).to receive(:parse).with('fake-cookie', URI.parse("https://some-host"))
          config.rest_client
        end

        it 'returns a new configured HTTPClient from hell' do
          expect(config.rest_client).to eq(rest_client)
        end
      end

      context 'when the rest client has already been created' do
        before { config.rest_client }

        it 'uses the cached client' do
          expect(HTTPClient).to_not receive(:new)
          config.rest_client
        end
      end
    end

    describe '#mem_overcommit' do
      context 'when set in config' do
        before { config_hash.merge!({ 'mem_overcommit_ratio' => 5.0 }) }

        it 'returns value set in config' do
          expect(config.mem_overcommit).to eql(5.0)
        end
      end

      context 'when not set in config' do
        it 'defaults to 1.0' do
          expect(config.mem_overcommit).to eql(1.0)
        end
      end
    end

    describe '#copy disks' do
      context 'when set in config' do
        before { config_hash.merge!({ 'copy_disks' => true }) }

        it 'returns true' do
          expect(config.copy_disks).to be(true)
        end
      end

      context 'when not set in config' do
        it 'false' do
          expect(config.copy_disks).to be(false)
        end
      end
    end

    describe '#agent' do
      it 'returns configuration values from config' do
        expect(config.agent).to eq(agent_config)
      end
    end

    describe '#vcenter_host' do
      it 'returns value from config' do
        expect(config.vcenter_host).to eq(host)
      end
    end

    describe '#vcenter_user' do
      it 'returns value from config' do
        expect(config.vcenter_user).to eq(user)
      end
    end

    describe '#vcenter_password' do
      it 'returns value from config' do
        expect(config.vcenter_password).to eq(password)
      end
    end

    describe '#datacenter_name' do
      it 'returns the datacenter name' do
        expect(config.datacenter_name).to eq datacenter_name
      end
    end

    describe '#datacenter_vm_folder' do
      it 'returns the datacenter vm folder name' do
        expect(config.datacenter_vm_folder).to eq(vm_folder)
      end
    end

    describe '#datacenter_template_folder' do
      it 'returns the datacenter template folder name' do
        expect(config.datacenter_template_folder).to eq(template_folder)
      end
    end

    describe '#datacenter_disk_path' do
      it 'returns the datacenter disk path  name' do
        expect(config.datacenter_disk_path).to eq(disk_path)
      end
    end

    describe '#datacenter_datastore_pattern' do
      it 'returns the datacenter datastore pattern ' do
        expect(config.datacenter_datastore_pattern).to eq(Regexp.new('fancy-datastore*'))
      end
    end

    describe '#datacenter_persistent_datastore_pattern' do
      it 'returns the datacenter persistent datastore pattern ' do
        expect(config.datacenter_persistent_datastore_pattern).to eq(Regexp.new(persistent_datastore_pattern))
      end
    end

    describe '#datacenter_allow_mixed' do
      context 'when allow_mixed is not set' do
        it 'returns false' do
          expect(config.datacenter_allow_mixed_datastores).to be(false)
        end
      end

      context 'when allow_mixed is falsey' do
        before { datacenters.first['allow_mixed_datastores'] = false }

        it 'returns false' do
          expect(config.datacenter_allow_mixed_datastores).to be(false)
        end
      end

      context 'when allow_mixed is truthy' do
        before { datacenters.first['allow_mixed_datastores'] = true }

        it 'returns true' do
          expect(config.datacenter_allow_mixed_datastores).to be(true)
        end
      end
    end

    describe '#datacenter_clusters' do

      context 'when there is more than one cluster' do
        before do
          datacenters.first['clusters'] = [
            { 'fake-cluster-1' => { 'resource_pool' => 'fake-resource-pool-1' } },
            { 'fake-cluster-2' => { 'resource_pool' => 'fake-resource-pool-2' } }
          ]
        end

        it 'returns the datacenter clusters' do
          expect(config.datacenter_clusters['fake-cluster-1'].name).to eq('fake-cluster-1')
          expect(config.datacenter_clusters['fake-cluster-1'].resource_pool).to eq('fake-resource-pool-1')

          expect(config.datacenter_clusters['fake-cluster-2'].name).to eq('fake-cluster-2')
          expect(config.datacenter_clusters['fake-cluster-2'].resource_pool).to eq('fake-resource-pool-2')
        end
      end

      context 'when the cluster is not found' do
        it 'returns the datacenter clusters' do
          expect(config.datacenter_clusters['does-not-exist']).to be_nil
        end
      end

      context 'when the clusters are strings in the config' do
        let(:client) { instance_double('VSphereCloud::Client') }

        before do
          allow(Client).to receive(:new).and_return(client)
          allow(client).to receive(:login)

          datacenters.first['clusters'] = [
            'fake-cluster-1',
            { 'fake-cluster-2' => { 'resource_pool' => 'fake-resource-pool-2' } }
          ]

        end

        it 'returns the datacenter clusters' do
          expect(config.datacenter_clusters['fake-cluster-1'].name).to eq('fake-cluster-1')
          expect(config.datacenter_clusters['fake-cluster-1'].resource_pool).to be(nil)

          expect(config.datacenter_clusters['fake-cluster-2'].name).to eq('fake-cluster-2')
          expect(config.datacenter_clusters['fake-cluster-2'].resource_pool).to eq('fake-resource-pool-2')
        end
      end
    end

    describe '#datacenter_use_sub_folder' do
      context 'when use sub folder is not set' do
        before { datacenters.first.delete('use_sub_folder') }

        context 'when no cluster has a resource pool' do
          before { datacenters.first['clusters'] = ['fake-cluster-1'] }

          it 'returns false' do
            expect(config.datacenter_use_sub_folder).to eq(false)
          end
        end
      end

      context 'when any cluster has a resource pool' do
        before do
          datacenters.first['clusters'] = [
            { 'fake-cluster-1' => { 'resource_pool' => 'fake-resource-pool-1' } }
          ]
        end

        it 'returns true' do
          expect(config.datacenter_use_sub_folder).to eq(true)
        end
      end
    end

    context 'when use sub folder is truthy' do
      before { datacenters.first['use_sub_folder'] = true }

      context 'when no cluster has a resource pool' do
        before { datacenters.first['clusters'] = ['fake-cluster-1'] }

        it 'returns false' do
          expect(config.datacenter_use_sub_folder).to eq(true)
        end
      end

      context 'when any cluster has a resource pool' do
        before do
          datacenters.first['clusters'] = [
            { 'fake-cluster-1' => { 'resource_pool' => 'fake-resource-pool-1' } }
          ]
        end

        it 'returns true' do
          expect(config.datacenter_use_sub_folder).to eq(true)
        end
      end
    end

    context 'when use sub folder is falsey' do
      before { datacenters.first['use_sub_folder'] = false }

      context 'when no cluster has a resource pool' do
        before { datacenters.first['clusters'] = ['fake-cluster-1'] }

        it 'returns false' do
          expect(config.datacenter_use_sub_folder).to eq(false)
        end
      end

      context 'when any cluster has a resource pool' do
        before do
          datacenters.first['clusters'] = [
            { 'fake-cluster-1' => { 'resource_pool' => 'fake-resource-pool-1' } }
          ]
        end

        it 'returns true' do
          expect(config.datacenter_use_sub_folder).to eq(true)
        end
      end
    end
  end
end
