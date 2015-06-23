require 'spec_helper'

#
# This supplants the config_old_spec.rb behavior. We are
# moving class behavior to instance behavior.
#

describe Bosh::Director::Config do
  let(:test_config) { Psych.load(spec_asset("test-director-config.yml")) }

  describe 'initialization' do
    it 'loads config from a yaml file' do
      config = described_class.load_file(asset("test-director-config.yml"))
      expect(config.name).to eq('Test Director')
    end

    it 'loads config from a hash' do
      config = described_class.load_hash(test_config)
      expect(config.name).to eq('Test Director')
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

  describe '#cloud' do
    before { described_class.configure(test_config) }

    it 'creates the cloud from the provider' do
      cloud = double('cloud')
      expect(Bosh::Clouds::Provider).to receive(:create).with(test_config['cloud'], described_class.uuid).and_return(cloud)
      expect(described_class.cloud).to equal(cloud)
    end

    it 'caches the cloud instance' do
      cloud = double('cloud')
      expect(Bosh::Clouds::Provider).to receive(:create).once.and_return(cloud)
      expect(described_class.cloud).to equal(cloud)
      expect(described_class.cloud).to equal(cloud)
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

  describe "#configure" do
    context "when the config specifies a file logger" do
      before { test_config["logging"]["file"] = "fake-file" }

      it "configures the logger with a file appender" do
        appender = Logging::Appender.new("file")
        expect(Logging.appenders).to receive(:file).with(
          'DirectorLogFile',
          hash_including(filename: 'fake-file')
        ).and_return(appender)
        described_class.configure(test_config)
      end
    end
  end

  describe '#identity_provider' do
    subject(:config) { Bosh::Director::Config.new(test_config) }
    let(:temp_dir) { Dir.mktmpdir }
    let(:base_config) do
      blobstore_dir = File.join(temp_dir, 'blobstore')
      FileUtils.mkdir_p(blobstore_dir)

      config = Psych.load(spec_asset('test-director-config.yml'))
      config['dir'] = temp_dir
      config['blobstore'] = {
        'provider' => 'local',
        'options' => {'blobstore_path' => blobstore_dir}
      }
      config['snapshots']['enabled'] = true
      config
    end
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
          user = config.identity_provider.get_user(request_env)
          expect(user.username).to eq('larry')
        end
      end
    end
  end

  describe '#override_uuid' do
    before { described_class.configure(test_config) }

    context 'when state.json exists' do
      let(:state_file) { File.join(test_config['dir'], 'state.json') }

      before do
        File.open(state_file, 'a+') { |f| f.write(JSON.dump({'uuid' => 'fake-uuid'})) }
      end

      after { FileUtils.rm_rf(state_file) }

      it 'migrates director uuid to database' do
        expect(described_class.override_uuid).to eq('fake-uuid')
        expect(Bosh::Director::Models::DirectorAttribute.first(name: 'uuid').value).to eq('fake-uuid')
      end
    end

    context 'when state.json does not exist' do
      it 'returns nil' do
        expect(described_class.override_uuid).to eq(nil)
      end
    end
  end
end
