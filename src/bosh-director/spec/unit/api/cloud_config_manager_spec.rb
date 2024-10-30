require 'spec_helper'

describe Bosh::Director::Api::CloudConfigManager do
  subject(:manager) { Bosh::Director::Api::CloudConfigManager.new }
  let(:valid_cloud_manifest) { YAML.dump(SharedSupport::DeploymentManifestHelper.simple_cloud_config) }
  let(:user) {'username-1'}
  let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}

  describe '#update' do
    it 'saves default cloud config' do
      expect {
        manager.update(valid_cloud_manifest)
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      cloud_config = Bosh::Director::Models::Config.first
      expect(cloud_config.created_at).to_not be_nil
      expect(cloud_config.content).to eq(valid_cloud_manifest)
      expect(cloud_config.name).to eq('default')
    end

    it 'saves named cloud config' do
      expect {
        manager.update(valid_cloud_manifest, 'foo-cloud-config')
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      cloud_config = Bosh::Director::Models::Config.first
      expect(cloud_config.created_at).to_not be_nil
      expect(cloud_config.content).to eq(valid_cloud_manifest)
      expect(cloud_config.name).to eq('foo-cloud-config')
    end

    context 'when cloud config uses placeholders' do
      let(:cloud_config_with_placeholders) { YAML.dump(SharedSupport::DeploymentManifestHelper.cloud_config_with_placeholders) }

      it 'does not error on update' do
        expect {
          manager.update(cloud_config_with_placeholders)
        }.to_not raise_error
      end
    end
  end

  describe '#list' do
    before(:each) do
      days = 24 * 60 * 60

      @oldest_cloud_config =
        FactoryBot.create(:models_config_cloud,
                          content: 'config_from_time_immortal',
                          created_at: Time.now - (3 * days))
      @older_cloud_config =
        FactoryBot.create(:models_config_cloud,
                          content: 'config_from_last_year',
                          created_at: Time.now - (2 * days))
      @newer_cloud_config =
        FactoryBot.create(:models_config_cloud,
                          content: "---\nsuper_shiny: new_config",
                          created_at: Time.now - (1 * days))
    end

    it 'returns the specified number of cloud configs (most recent first)' do
      cloud_configs = manager.list(2)

      expect(cloud_configs.count).to eq(2)
      expect(cloud_configs[0]).to eq(@newer_cloud_config)
      expect(cloud_configs[0].content).to eq( "---\nsuper_shiny: new_config")
      expect(cloud_configs[1]).to eq(@older_cloud_config)
    end

    context 'when there are deleted cloud configs' do
      before(:each) do
        @older_cloud_config.update(deleted: true)
      end

      it 'ignores the deleted configs from the result' do
        cloud_configs = manager.list(3)

        expect(cloud_configs.count).to eq(2)
        expect(cloud_configs[0]).to eq(@newer_cloud_config)
        expect(cloud_configs[0].content).to eq( "---\nsuper_shiny: new_config")
        expect(cloud_configs[1]).to eq(@oldest_cloud_config)
      end
    end

    context 'when name is specified' do
      let(:name){ 'some-foo-name'}

      it 'returns the specified number of cloud configs (most recent first)' do
        named_config1 = Bosh::Director::Models::Config.new(type: 'cloud', content: 'named_config', name: 'some-foo-name').save
        Bosh::Director::Models::Config.new(type: 'cloud', content: 'default_config', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'cloud', content: 'default_config', name: 'some-other-foo-name').save
        named_config2 = Bosh::Director::Models::Config.new(type: 'cloud', content: 'named_config2', name: 'some-foo-name').save

        runtime_configs = manager.list(2, name)

        expect(runtime_configs).to eq([named_config2, named_config1])
      end
    end
  end

  describe '.interpolated_manifest' do
    let(:cloud_configs) { [FactoryBot.create(:models_config_cloud, content: YAML.dump(raw_manifest))] }
    let(:raw_manifest) do
      { 'azs' => [{ name: '((az_name))' }], 'vm_types' => [], 'disk_types' => [], 'networks' => [], 'vm_extensions' => [] }
    end
    let(:interpolated_manifest) do
      { 'azs' => [{ name: 'blah' }], 'vm_types' => [], 'disk_types' => [], 'networks' => [], 'vm_extensions' => [] }
    end
    let(:deployment_name) { 'some_deployment_name' }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    before do
      allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
      allow(variables_interpolator).to receive(:interpolate_cloud_manifest).with(raw_manifest, deployment_name).and_return(interpolated_manifest)
    end

    it 'returns interpolated manifest' do
      result = Bosh::Director::Api::CloudConfigManager.interpolated_manifest(cloud_configs, deployment_name)
      expect(result).to eq(interpolated_manifest)
    end
  end
end
