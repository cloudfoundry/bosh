require 'spec_helper'

#
# This supplants the config_old_spec.rb behavior. We are
# moving class behavior to instance behavior.
#

describe Bosh::Director::Config do
  let(:test_config) { YAML.load(spec_asset('test-director-config.yml')) }
  let(:temp_dir) { Dir.mktmpdir }
  let(:base_config) do
    blobstore_dir = File.join(temp_dir, 'blobstore')
    FileUtils.mkdir_p(blobstore_dir)

    config = YAML.load(spec_asset('test-director-config.yml'))
    config['dir'] = temp_dir
    config['blobstore'] = {
        'provider' => 'local',
        'options' => {
            'blobstore_path' => blobstore_dir,
        }
    }
    config['snapshots']['enabled'] = true
    config
  end

  describe 'initialization' do
    it 'loads config from a yaml file' do
      config = described_class.load_file(asset('test-director-config.yml'))
      expect(config.name).to eq('Test Director')
    end

    it 'loads config from a hash' do
      config = described_class.load_hash(test_config)
      expect(config.name).to eq('Test Director')
    end
  end

  describe 'director ips' do
    before do
      allow(Socket).to receive(:ip_address_list).and_return([
        instance_double(Addrinfo, ip_address: '127.0.0.1', ip?: true, ipv4?: true, ipv6?: false, ipv4_loopback?: true, ipv6_loopback?: false),
        instance_double(Addrinfo, ip_address: '10.10.0.6', ip?: true, ipv4?: true, ipv6?: false, ipv4_loopback?: false, ipv6_loopback?: false),
        instance_double(Addrinfo, ip_address: '10.11.0.16', ip?: true, ipv4?: true, ipv6?: false, ipv4_loopback?: false, ipv6_loopback?: false),
        instance_double(Addrinfo, ip_address: '::1', ip?: true, ipv4?: false, ipv6?: true, ipv4_loopback?: false, ipv6_loopback?: true),
        instance_double(Addrinfo, ip_address: 'fe80::10bf:eff:fe2c:7405%eth0', ip?: true, ipv4?: false, ipv6?: true, ipv4_loopback?: false, ipv6_loopback?: false),
      ])
    end

    it 'should select the non-loopback, ipv4 ips off of the the Socket class' do
      described_class.configure(test_config)
      expect(described_class.director_ips).to eq(['10.10.0.6','10.11.0.16'])
    end
  end

  describe '#max_create_vm_retries' do
    context 'when hash has value set' do
      it 'returns the configuration value' do
        test_config['max_vm_create_tries'] = 3
        described_class.configure(test_config)
        expect(described_class.max_vm_create_tries).to eq(3)
      end
    end

    context 'when hash does not have value set' do
      it 'returns default value of five as per previous behavior' do
        # our fixture does not have this set so this is a no-op
        # i'm doing this because i want to be more explicit
        test_config.delete('max_vm_create_tries')
        described_class.configure(test_config)
        expect(described_class.max_vm_create_tries).to eq(5)
      end
    end

    context 'when hash contains a non integral value' do
      it 'raises an error' do
        test_config['max_vm_create_tries'] = 'bad number'
        expect{
          described_class.configure(test_config)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#flush_arp' do
    context 'when hash has value set' do
      it 'returns the configuration value' do
        test_config['flush_arp'] = true
        described_class.configure(test_config)
        expect(described_class.flush_arp).to eq(true)
      end
    end

    context 'when hash does not have value set' do
      it 'returns default value of false' do
        # our fixture does not have this set so this is a no-op
        # i'm doing this because the test we copied did it
        test_config.delete('flush_arp')
        described_class.configure(test_config)
        expect(described_class.flush_arp).to eq(false)
      end
    end
  end

  describe '#local_dns' do
    context 'when hash has value set' do
      it 'returns the configuration value' do
        test_config['local_dns']['enabled'] = true
        described_class.configure(test_config)
        expect(described_class.local_dns_enabled?).to eq(true)
      end
    end

    context 'when hash does not have value set' do
      it 'returns default value of false' do
        described_class.configure(test_config)
        expect(described_class.local_dns_enabled?).to eq(false)
      end
    end
  end

  describe '#keep_unreachable_vms' do
    context 'when hash has value set' do
      it 'returns the configuration value' do
        test_config['keep_unreachable_vms'] = true
        described_class.configure(test_config)
        expect(described_class.keep_unreachable_vms).to eq(true)
      end
    end

    context 'when hash does not have value set' do
      it 'returns default value of false' do
        test_config.delete('keep_unreachable_vms')
        described_class.configure(test_config)
        expect(described_class.keep_unreachable_vms).to eq(false)
      end
    end
  end

  describe '#cpi_task_log' do
    before do
      described_class.configure(test_config)
      described_class.cloud_options['properties']['cpi_log'] = 'fake-cpi-log'
    end

    it 'returns cpi task log' do
      expect(described_class.cpi_task_log).to eq('fake-cpi-log')
    end
  end

  describe '#configure' do
    context 'when the config specifies a file logger' do
      before { test_config['logging']['file'] = 'fake-file' }

      it 'configures the logger with a file appender' do
        appender = Logging::Appender.new('file')
        expect(Logging.appenders).to receive(:file).with(
          'DirectorLogFile',
          hash_including(filename: 'fake-file')
        ).and_return(appender)
        described_class.configure(test_config)
      end
    end

    context 'config server' do
      context 'when enabled' do
        before {
          test_config['config_server'] = {
              'enabled' => true,
              'url' => 'https://127.0.0.1:8080',
              'ca_cert_path' => '/var/vcap/jobs/director/config/config_server_ca.cert'
          }

          test_config['config_server']['uaa'] = {
              'url' => 'fake-uaa-url',
              'client_id' => 'fake-client-id',
              'client_secret' => 'fake-client-secret',
              'ca_cert_path' => 'fake-uaa-ca-cert-path'
          }
        }

        it 'should have parsed out config server values' do
          described_class.configure(test_config)

          expect(described_class.config_server['url']).to eq('https://127.0.0.1:8080')
          expect(described_class.config_server['ca_cert_path']).to eq('/var/vcap/jobs/director/config/config_server_ca.cert')

          expect(described_class.config_server['uaa']['url']).to eq('fake-uaa-url')
          expect(described_class.config_server['uaa']['client_id']).to eq('fake-client-id')
          expect(described_class.config_server['uaa']['client_secret']).to eq('fake-client-secret')
          expect(described_class.config_server['uaa']['ca_cert_path']).to eq('fake-uaa-ca-cert-path')
        end

        context 'config server urls' do
          it 'should return an array of urls' do
            described_class.configure(test_config)
            config = Bosh::Director::Config.new(test_config)
            expect(config.config_server_urls).to eq(['https://127.0.0.1:8080'])
          end
        end

        context 'when url is not https' do
          before {
            test_config["config_server"]["url"] = "http://127.0.0.1:8080"
          }

          it 'errors' do
            expect {  described_class.configure(test_config) }.to raise_error(ArgumentError, 'Config Server URL should always be https. Currently it is http://127.0.0.1:8080')
          end
        end
      end

      context 'when disabled' do
        before {
          test_config["config_server_enabled"] = false
        }

        it 'should not have parsed out the values' do
          described_class.configure(test_config)

          expect(described_class.config_server).to eq({"enabled"=>false})
        end
      end
    end

    describe 'enable_nats_delivered_templates' do
      it 'defaults to false' do
        described_class.configure(test_config)
        expect(described_class.enable_nats_delivered_templates).to be_falsey
      end

      context 'when explicitly set' do
        context 'when set to true' do
          before { test_config['enable_nats_delivered_templates'] = true }

          it 'resolves to true' do
            described_class.configure(test_config)
            expect(described_class.enable_nats_delivered_templates).to be_truthy
          end
        end

        context 'when set to false' do
          before { test_config['enable_nats_delivered_templates'] = false }

          it 'resolves to false' do
            described_class.configure(test_config)
            expect(described_class.enable_nats_delivered_templates).to be_falsey
          end
        end
      end
    end

    describe 'director version' do
      it 'sets the expected version/revision' do
        described_class.configure(test_config)
        expect(described_class.revision).to match /^[0-9a-f]{8}$/
        expect(described_class.version).to eq('0.0.2')
      end
    end
  end

  describe '#identity_provider' do
    subject(:config) { Bosh::Director::Config.new(test_config) }
    let(:provider_options) { {'blobstore_path' => blobstore_dir} }

    after { FileUtils.rm_rf(temp_dir) }

    describe 'authentication configuration' do
      let(:test_config) { base_config.merge({'user_management' => {'provider' => provider}}) }

      context 'when no user_management config is specified' do
        let(:test_config) { base_config }

        it 'uses LocalIdentityProvider' do
          expect(config.identity_provider).to be_a(Bosh::Director::Api::LocalIdentityProvider)
        end
      end

      context 'when local provider is supplied' do
        let(:provider) { 'local' }

        it 'uses LocalIdentityProvider' do
          expect(config.identity_provider).to be_a(Bosh::Director::Api::LocalIdentityProvider)
        end
      end

      context 'when a bogus provider is supplied' do
        let(:provider) { 'wrong' }

        it 'should raise an error' do
          expect { config.identity_provider }.to raise_error(ArgumentError)
        end
      end

      context 'when uaa provider is supplied' do
        let(:provider) { 'uaa' }
        let(:provider_options) { {'symmetric_key' => 'some-key', 'url' => 'some-url'} }
        let(:token) { CF::UAA::TokenCoder.new(skey: 'some-key').encode(payload) }
        let(:payload) { {'user_name' => 'larry', 'aud' => ['bosh_cli'], 'scope' => ['bosh.admin']} }
        before { test_config['user_management']['uaa'] = provider_options }

        it 'creates a UAAIdentityProvider' do
          expect(config.identity_provider).to be_a(Bosh::Director::Api::UAAIdentityProvider)
        end

        it 'creates the UAAIdentityProvider with the configured key' do
          request_env = {'HTTP_AUTHORIZATION' => "bearer #{token}"}
          user = config.identity_provider.get_user(request_env, {})
          expect(user.username).to eq('larry')
        end
      end
    end
  end

  describe '#root_domain' do
    context 'when no dns_domain is set in config' do
      let(:test_config) { base_config.merge({'dns' => {}}) }
      it 'returns bosh' do
        described_class.configure(test_config)
        expect(described_class.root_domain).to eq('bosh')
      end
    end

    context 'when dns_domain is set in config' do
      let(:test_config) { base_config.merge({'dns' => {'domain_name' => 'test-domain-name'}}) }
      it 'returns the DNS domain' do
        described_class.configure(test_config)
        expect(described_class.root_domain).to eq('test-domain-name')
      end
    end
  end

  describe '#name' do
    subject(:config) { Bosh::Director::Config.new(test_config) }

    it 'returns the name specified in the config' do
      expect(config.name).to eq('Test Director')
    end
  end

  describe '#port' do
    subject(:config) { Bosh::Director::Config.new(test_config) }

    it 'returns the port specified in the config' do
      expect(config.port).to eq(8081)
    end
  end

  describe '#version' do
    subject(:config) { Bosh::Director::Config.new(test_config) }

    it 'returns the version specified in the config' do
      expect(config.version).to eq('0.0.2')
    end
  end

  describe 'log_director_start_event' do
    it 'stores an event' do
      described_class.configure(test_config)

      expect {
        described_class.log_director_start_event('custom-type', 'custom-name', {'custom' => 'context'})
      }.to change {
        Bosh::Director::Models::Event.count
      }.from(0).to(1)

      expect(Bosh::Director::Models::Event.count).to eq(1)
      event = Bosh::Director::Models::Event.first
      expect(event.user).to eq('_director')
      expect(event.action).to eq('start')
      expect(event.object_type).to eq('custom-type')
      expect(event.object_name).to eq('custom-name')
      expect(event.context).to eq({'custom' => 'context'})
    end
  end

  context 'multiple digest' do
    context 'when verify multidigest is provided' do
      it 'allows access to multidigest path' do
        described_class.configure(base_config)
        expect(described_class.verify_multidigest_path).to eq('/some/path')
      end
    end

    context 'when verify multidigest is not provided' do
      before do
        base_config['verify_multidigest_path'] = nil
      end

      it 'raises an error' do
        expect{ described_class.configure(base_config) }.to raise_error(ArgumentError)
      end
    end
  end

  context 'when director starts' do
    it 'stores start event' do
      allow(SecureRandom).to receive(:uuid).and_return('director-uuid')
      described_class.configure(test_config)
      expect {
        described_class.log_director_start
      }.to change {
        Bosh::Director::Models::Event.count }.from(0).to(1)
      expect(Bosh::Director::Models::Event.count).to eq(1)
      event = Bosh::Director::Models::Event.first
      expect(event.user).to eq('_director')
      expect(event.action).to eq('start')
      expect(event.object_type).to eq('director')
      expect(event.object_name).to eq('director-uuid')
      expect(event.context).to eq({'version' => '0.0.2'})
    end
  end

  describe 'enable_cpi_resize_disk' do
    it 'defaults to false' do
      described_class.configure(test_config)
      expect(described_class.enable_cpi_resize_disk).to be_falsey
    end

    context 'when explicitly set' do
      context 'when set to true' do
        before { test_config['enable_cpi_resize_disk'] = true }

        it 'resolves to true' do
          described_class.configure(test_config)
          expect(described_class.enable_cpi_resize_disk).to be_truthy
        end
      end

      context 'when set to false' do
        before { test_config['enable_cpi_resize_disk'] = false }

        it 'resolves to false' do
          described_class.configure(test_config)
          expect(described_class.enable_cpi_resize_disk).to be_falsey
        end
      end
    end
  end
end
