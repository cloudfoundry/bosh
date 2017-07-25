require 'spec_helper'

describe Bosh::Director::Api::TasksConfigManager do
  subject(:manager) { Bosh::Director::Api::TasksConfigManager.new }
  let(:valid_tasks_manifest) { YAML.dump(Bosh::Spec::Deployments.simple_task_config) }
  let(:user) {'username-1'}
  let(:event_manager) {Bosh::Director::Api::EventManager.new(true)}

  describe '#update' do
    it 'saves the tasks config' do
      expect {
        manager.update(valid_tasks_manifest)
      }.to change(Bosh::Director::Models::TasksConfig, :count).from(0).to(1)

      tasks_config = Bosh::Director::Models::TasksConfig.first
      expect(tasks_config.created_at).to_not be_nil
      expect(tasks_config.properties).to eq(valid_tasks_manifest)
    end

    context 'when tasks config is not valid YAML' do
      it 'returns an error' do
        tasks_config_yaml = ':'
        expect {
          manager.update(tasks_config_yaml)
        }.to raise_error Bosh::Director::InvalidYamlError
        expect(Bosh::Director::Models::TasksConfig.count).to eq(0)
      end
    end
  end

  describe '#list' do
    it 'returns the specified number of tasks configs (most recent first)' do
      days = 24*60*60

      oldest_tasks_config = Bosh::Director::Models::TasksConfig.new(
          properties: 'config_from_time_immortal',
          created_at: Time.now - 3*days,
      ).save
      older_tasks_config = Bosh::Director::Models::TasksConfig.new(
          properties: 'config_from_last_year',
          created_at: Time.now - 2*days,
      ).save
      newer_tasks_config = Bosh::Director::Models::TasksConfig.new(
          properties: "---\nsuper_shiny: new_config",
          created_at: Time.now - 1*days,
      ).save

      task_configs = manager.list(2)

      expect(task_configs.count).to eq(2)
      expect(task_configs[0]).to eq(newer_tasks_config)
      expect(task_configs[1]).to eq(older_tasks_config)
    end
  end

  describe '#latest' do
    it 'returns the latest' do
      days = 24*60*60

      older_tasks_config = Bosh::Director::Models::TasksConfig.new(
          properties: 'config_from_last_year',
          created_at: Time.now - 2*days,
      ).save
      newer_tasks_config = Bosh::Director::Models::TasksConfig.new(
          properties: "---\nsuper_shiny: new_config",
          created_at: Time.now - 1*days,
      ).save

      tasks_config = manager.latest

      expect(tasks_config).to eq(newer_tasks_config)
    end

    it 'returns nil if there are no tasks configs' do
      tasks_config = manager.latest

      expect(tasks_config).to be_nil
    end
  end
end
