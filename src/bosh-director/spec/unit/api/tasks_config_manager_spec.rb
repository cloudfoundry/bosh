require 'spec_helper'
require 'delayed_job'

module Bosh::Director
  describe Api::TasksConfigManager do
    def handler(task_id)
      "--- !ruby/object:Bosh::Director::Jobs::DBJob\n" \
        "job_class: !ruby/class 'Bosh::Director::Jobs::UpdateDeployment'\ntask_id: #{task_id}"
    end

    def load_configs(content)
      Models::Config.create(
        type: 'tasks',
        name: 'tasks',
        content: content,
      )
      manager.rebuild_groups
    end

    let(:manager) { described_class.new }
    subject(:config_manager) { Api::ConfigManager.new }

    let(:tasks_configs_content) do
      {
        'rules' => [
          tasks_config_1,
        ],
      }
    end

    let(:tasks_config_1) do
      {
        'options' => { 'rate_limit' => 0 },
        'include' => include_spec,
        'exclude' => exclude_spec,
      }
    end

    let(:tasks_config_2) do
      {
        'options' => { 'rate_limit' => 1 },
      }
    end

    let(:include_spec) do
      {
        'deployments' => ['deployment_include'],
        'teams' => ['team-1'],
      }
    end
    let(:exclude_spec) { { 'deployments' => ['deployment_exclude'] } }
    let(:task) { make_task_with_team(id: 43, state: :queued, deployment_name: 'deployment_include', teams: teams) }
    let(:teams) do
      [Models::Team.make(name: 'team-1'), Bosh::Director::Models::Team.make(name: 'team-2')]
    end

    describe '#rebuild_groups' do
      it 'creates new groups' do
        load_configs(YAML.dump(tasks_configs_content))
        expect(Models::DelayedJobGroup.count).to eq(1)
        groups = Models::DelayedJobGroup.all
        expect(groups[0].config_content).to eq(YAML.dump(tasks_configs_content['rules'][0]))
        expect(groups[0].limit).to eq(0)
      end

      it 'adds a job to the group' do
        job = Delayed::Job.create(
          priority: 1,
          attempts: 2,
          handler: handler(task.id),
          queue: 'test',
        )

        load_configs(YAML.dump(tasks_configs_content))
        expect(job.delayed_job_groups.count).to eq(1)
      end

      context 'when groups already exist' do
        it 'does a cleanup' do
          load_configs(YAML.dump(tasks_configs_content))
          groups = Models::DelayedJobGroup.all

          load_configs(YAML.dump(tasks_configs_content))
          new_groups = Models::DelayedJobGroup.all
          expect(groups.size).to eq(1)
          expect(new_groups.size).to eq(1)
          expect((new_groups - groups).empty?).to be_falsey
        end
      end
    end

    describe '#add_to_groups' do
      let(:job) do
        Delayed::Job.create(
          priority: 1,
          attempts: 2,
          handler: handler(task.id),
          queue: 'test',
        )
      end

      it 'does not raise when unique constraint failed' do
        load_configs(YAML.dump(tasks_configs_content))
        manager.add_to_groups(job)
        manager.add_to_groups(job)
        expect(job.delayed_job_groups.count).to eq(1)
      end

      context 'when the tasks_config is applicable by deployment name' do
        let(:include_spec) { { 'deployments' => ['deployment_include'] } }

        it 'applies' do
          load_configs(YAML.dump(tasks_configs_content))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(1)
        end
      end

      context 'when the tasks_config is not applicable by deployment name' do
        let(:include_spec) { { 'deployments' => ['no_findy'] } }

        it 'does not apply' do
          load_configs(YAML.dump(tasks_configs_content))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(0)
        end
      end

      context 'when the tasks_config is applicable by teams' do
        let(:include_spec) { { 'teams' => ['team-1'] } }

        it 'applies' do
          load_configs(YAML.dump(tasks_configs_content))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(1)
        end
      end

      context 'when the tasks_config is not applicable by teams' do
        let(:include_spec) { { 'teams' => ['team_3'] } }

        it 'does not apply' do
          load_configs(YAML.dump(tasks_configs_content))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(0)
        end
      end

      context 'when the tasks_config has empty include and exclude' do
        let(:include_spec) { {} }
        let(:exclude_spec) { {} }

        it 'applies' do
          load_configs(YAML.dump(tasks_configs_content))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(1)
        end
      end

      context 'when the tasks_config has include and exclude' do
        let(:include_spec) { { 'deployments' => ['deployment_include'] } }

        context 'when they are the same' do
          let(:exclude_spec) { { 'deployments' => ['deployment_include'] } }

          it 'does not apply' do
            load_configs(YAML.dump(tasks_configs_content))
            manager.add_to_groups(job)
            expect(job.delayed_job_groups.count).to eq(0)
          end
        end

        context 'when include is for deployment and exlude is for team' do
          let(:exclude_spec) { { 'teams' => ['team-1', 'team-2'] } }

          it 'does not apply' do
            load_configs(YAML.dump(tasks_configs_content))
            manager.add_to_groups(job)
            expect(job.delayed_job_groups.count).to eq(0)
          end
        end
      end

      context 'when there are several groups' do
        it 'applies for all applicable groups' do
          tasks_configs_content_extended =
            {
              'rules' => [
                tasks_config_1,
                tasks_config_2,
              ],
            }
          load_configs(YAML.dump(tasks_configs_content_extended))
          manager.add_to_groups(job)
          expect(job.delayed_job_groups.count).to eq(2)
        end
      end
    end
  end
end
