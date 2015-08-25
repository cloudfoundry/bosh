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

  context 'when external cpi is not enabled' do
    let(:name) { 'spec' }
    let(:cloud) { Bosh::Clouds::Spec.new(anything) }
    let(:proxy) { Bosh::Clouds::InternalCpi.new(cloud) }
    let(:settings) { { 'key' => 'original' } }
    let(:config) do
      {
        'plugin' => name,
        'properties' => {}
      }
    end

    it 'provides an internal cpi proxy instance' do
      expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
      expect(Bosh::Clouds::Provider.create(config, director_uuid)).to equal(proxy)
    end

    describe 'a method on the proxy instance' do
      it 'proxies to the cpi implementation' do
        expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
        Bosh::Clouds::Provider.create(config, director_uuid)

        expect(cloud).to receive(:create_vm)
        proxy.create_vm(settings)
      end

      context 'when the cpi implementation exists' do
        it 'returns true for #respond_to?' do
          expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
          Bosh::Clouds::Provider.create(config, director_uuid)

          expect(proxy.respond_to?(:create_vm)).to be(true)
        end
      end

      context 'when the cpi implementation does not exist' do
        it 'raises an exception from the cpi implementation' do
          expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
          Bosh::Clouds::Provider.create(config, director_uuid)

          expect {
            proxy.something
          }.to raise_error(NoMethodError, /Bosh::Clouds::Spec/)
        end

        it 'returns false for #respond_to?' do
          expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
          Bosh::Clouds::Provider.create(config, director_uuid)

          expect(proxy.respond_to?(:something)).to be(false)
        end
      end
    end

    describe 'a method on the cpi implementation' do
      it 'does not modify the provided configuration' do
        expect(Bosh::Clouds::InternalCpi).to receive(:new).and_return(proxy)
        Bosh::Clouds::Provider.create(config, director_uuid)

        expect {
          proxy.create_vm(settings)
        }.to_not change { settings }
        expect(cloud.settings['key']).to eq('modified')
      end
    end

    context 'given an invalid cpi name' do
      let(:name) { 'enoent' }

      it 'fails to create provider' do
        expect {
          Bosh::Clouds::Provider.create(config, director_uuid)
        }.to raise_error(Bosh::Clouds::CloudError, /Could not load Cloud Provider Plugin: enoent/)
      end
    end
  end
end
