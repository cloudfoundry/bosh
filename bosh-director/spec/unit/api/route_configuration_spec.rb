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

    after { FileUtils.rm_rf(temp_dir) }

    context 'when no authentication configuration is supplied' do
      let(:test_config) { base_config }

      it 'defaults to LocalIdentityProvider' do
        route_configuration.controllers.each do |route, controller|
          identity_provider = controller.instance_variable_get(:"@instance").identity_provider
          expect(identity_provider).to be_a(Api::LocalIdentityProvider)
        end
      end
    end

    context 'when uaa configuration is supplied' do
      let(:test_config) { base_config.merge({ 'user_management' => { 'provider' => 'uaa' }}) }

      it 'creates controllers with a UAAIdentityProvider' do
        route_configuration.controllers.each do |route, controller|
          identity_provider = controller.instance_variable_get(:"@instance").identity_provider
          expect(identity_provider).to be_a(Api::UAAIdentityProvider)
        end
      end
    end
  end
end

