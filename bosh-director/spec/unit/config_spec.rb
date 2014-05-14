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
      expect(config.hash).to include('name' => 'Test Director')
    end

    it 'loads config from a hash' do
      config = described_class.load_hash(test_config)
      expect(config.hash).to include('name' => 'Test Director')
    end
  end

  describe '#max_create_vm_retries' do
    context 'when hash has value set' do
      it 'returns the configuration value' do
        test_config['max_vm_create_tries'] = 3

        config = described_class.load_hash(test_config)
        described_class.configure(config.hash)

        expect(described_class.max_vm_create_tries).to eq(3)
      end
    end

    context 'when hash does not have value set' do
      it 'returns default value of five as per previous behavior' do
        # our fixture does not have this set so this is a no-op
        # i'm doing this because i want to be more explicit
        test_config.delete('max_vm_create_tries')

        config = described_class.load_hash(test_config)
        described_class.configure(config.hash)

        expect(described_class.max_vm_create_tries).to eq(5)
      end
    end

    context 'when hash contains a non integral value' do
      it 'raises an error' do
        test_config['max_vm_create_tries'] = 'bad number'

        config = described_class.load_hash(test_config)
        expect{
          described_class.configure(config.hash)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#cloud' do
    before do
      config = described_class.load_hash(test_config)
      described_class.configure(config.hash)
    end

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
      config = described_class.load_hash(test_config)
      described_class.configure(config.hash)
      described_class.cloud_options['properties']['cpi_log'] = 'fake-cpi-log'
    end

    it 'returns cpi task log' do
      expect(described_class.cpi_task_log).to eq('fake-cpi-log')
    end
  end
end
