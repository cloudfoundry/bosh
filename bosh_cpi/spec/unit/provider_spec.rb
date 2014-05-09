require 'spec_helper'
require 'cloud/spec'

describe Bosh::Clouds::Provider do
  let(:director_uuid) { 'fake-director-uuid' }

  context 'when external cpi is enabled' do
    let(:config) do
      {
        'external_cpi' => {
          'enabled' => true,
          'cpi_path' => '/path/to/fake-external-cpi'
        }
      }
    end

    it 'provides external cpi cloud' do
      provider = instance_double('Bosh::Clouds::ExternalCpi')
      expect(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/fake-external-cpi', director_uuid).and_return(provider)
      expect(Bosh::Clouds::Provider.create(config, director_uuid)).to equal(provider)
    end
  end

  context 'when external cpi is not enabled' do
    let(:plugin_name) { 'spec' }
    let(:config) do
      {
        'plugin' => plugin_name,
        'properties' => {}
      }
    end

    it 'creates a plugin cpi provider instance' do
      provider = instance_double('Bosh::Clouds::ExternalCpi')
      expect(Bosh::Clouds::Spec).to receive(:new).with({}).and_return(provider)
      expect(Bosh::Clouds::Provider.create(config, director_uuid)).to equal(provider)
    end

    context 'when invalid plugin name' do
      let(:plugin_name) { 'enoent' }

      it 'fails to create provider' do
        expect {
          Bosh::Clouds::Provider.create(config, director_uuid)
        }.to raise_error(Bosh::Clouds::CloudError, /Could not load Cloud Provider Plugin: enoent/)
      end
    end
  end
end
