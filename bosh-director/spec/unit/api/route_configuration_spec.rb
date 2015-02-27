require 'spec_helper'

module Bosh::Director
  describe Api::RouteConfiguration do
    subject(:route_configuration) { Api::RouteConfiguration.new(config) }
    let(:temp_dir) { Dir.mktmpdir }
    let(:config) do
      Config.load_hash(test_config)
    end
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
          route_configuration.controllers.each do |route, controller|
            identity_provider = controller.instance_variable_get(:"@instance").identity_provider
            expect(identity_provider).to be_a(Api::LocalIdentityProvider)
          end
        end
      end

      context 'when local provider is supplied' do
        let(:provider) { 'local' }

        it 'uses LocalIdentityProvider' do
          route_configuration.controllers.each do |route, controller|
            identity_provider = controller.instance_variable_get(:"@instance").identity_provider
            expect(identity_provider).to be_a(Api::LocalIdentityProvider)
          end
        end
      end

      context 'when a bogus provider is supplied' do
        let(:provider) { 'wrong' }

        it 'should raise an error' do
          expect { route_configuration.controllers }.to raise_error(ArgumentError)
        end
      end

      context 'when uaa provider is supplied' do
        let(:provider) { 'uaa' }
        let(:provider_options) { {'key' => 'some-key'} }
        let(:token) { CF::UAA::TokenCoder.new(skey: 'some-key').encode(payload) }
        let(:payload) { {'user_id' => 'larry', 'aud' => ['bosh']} }
        before { test_config['user_management']['options'] = provider_options }

        it 'creates controllers with a UAAIdentityProvider' do
          route_configuration.controllers.each do |route, controller|
            identity_provider = controller.instance_variable_get(:"@instance").identity_provider
            expect(identity_provider).to be_a(Api::UAAIdentityProvider)
          end
        end

        it 'creates the UAAIdentityProvider with the configured key' do
          route_configuration.controllers.each do |route, controller|
            identity_provider = controller.instance_variable_get(:"@instance").identity_provider
            request_env = {'HTTP_AUTHORIZATION' => "bearer #{token}"}
            expect(identity_provider.corroborate_user(request_env)).to eq('larry')
          end
        end
      end
    end
  end
end

