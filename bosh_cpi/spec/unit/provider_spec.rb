require 'spec_helper'
require 'cloud/spec'

describe Bosh::Clouds::Provider do
  let(:director_uuid) { 'director-uuid' }

  context 'when external cpi is enabled' do
    let(:config) do
      {
        'provider' => {
          'name' => 'test-cpi',
          'path' => '/path/to/test-cpi/bin/cpi'
        }
      }
    end

    it 'provides an external cpi proxy instance' do
      proxy = instance_double('Bosh::Clouds::ExternalCpi')
      expect(Bosh::Clouds::ExternalCpi).to receive(:new)
        .with('/path/to/test-cpi/bin/cpi', director_uuid)
        .and_return(proxy)
      expect(Bosh::Clouds::Provider.create(config, director_uuid)).to equal(proxy)
    end
  end
end
