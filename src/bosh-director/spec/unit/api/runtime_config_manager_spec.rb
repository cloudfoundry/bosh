require 'spec_helper'

describe Bosh::Director::Api::RuntimeConfigManager do
  subject(:manager) { Bosh::Director::Api::RuntimeConfigManager.new }
  let(:valid_runtime_manifest) { YAML.dump(Bosh::Spec::Deployments.simple_runtime_config) }

  describe '#update' do
    it 'saves default runtime config' do
      expect {
        manager.update(valid_runtime_manifest)
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      runtime_config = Bosh::Director::Models::Config.first
      expect(runtime_config.created_at).to_not be_nil
      expect(runtime_config.content).to eq(valid_runtime_manifest)
      expect(runtime_config.name).to eq('default')
    end

    it 'saves named runtime config' do
      expect {
        manager.update(valid_runtime_manifest, 'foo-runtime')
      }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      runtime_config = Bosh::Director::Models::Config.first
      expect(runtime_config.created_at).to_not be_nil
      expect(runtime_config.content).to eq(valid_runtime_manifest)
      expect(runtime_config.name).to eq('foo-runtime')
    end

    it 'throws an error if runtime config is not valid YAML' do
      invalid_manifest = ":"
      expect{
        manager.update(invalid_manifest)
      }.to raise_error Bosh::Director::InvalidYamlError
    end
  end

  describe '#list' do
    it 'returns the specified number of runtime configs (most recent first)' do
      Bosh::Director::Models::Config.new(type: 'runtime', content: 'config_from_time_immortal', name: 'default').save
      older_runtime_config = Bosh::Director::Models::Config.new(type: 'runtime', content: 'config_from_yesteryear', name: 'default').save
      Bosh::Director::Models::Config.new(type: 'runtime', content: 'named_config2', name: 'some-foo-name').save
      newer_runtime_config = Bosh::Director::Models::Config.new(type: 'runtime', content: "---\nsuper_shiny: new_config", name: 'default').save

      runtime_configs = manager.list(2)

      expect(runtime_configs).to eq([newer_runtime_config, older_runtime_config])
    end

    context 'when name is specified' do
      let(:name){ 'some-foo-name'}

      it 'returns the specified number of runtime configs (most recent first)' do
        named_config1 = Bosh::Director::Models::Config.new(type: 'runtime', content: 'named_config', name: 'some-foo-name').save
        Bosh::Director::Models::Config.new(type: 'runtime', content: 'default_config', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'runtime', content: 'default_config', name: 'some-other-foo-name').save
        named_config2 = Bosh::Director::Models::Config.new(type: 'runtime', content: 'named_config2', name: 'some-foo-name').save

        runtime_configs = manager.list(2, name)

        expect(runtime_configs).to eq([named_config2, named_config1])
      end
    end
  end
end
